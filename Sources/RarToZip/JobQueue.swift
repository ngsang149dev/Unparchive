import Foundation

enum JobMode: Sendable {
    case convertToZip
    case extract
}

enum JobResult: Sendable {
    case success(URL)
    case cancelled
    case failure(String)
}

final class JobQueue: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.ngsang.RarToZip.jobs")
    private let converter = ConversionService()
    private let lock = NSLock()
    private var pending = 0

    var isBusy: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pending > 0
    }

    func enqueue(
        archives: [URL],
        mode: JobMode,
        compression: CompressionLevel = .fast,
        perItem: @escaping @MainActor (URL, JobResult) -> Void,
        completion: @escaping @MainActor () -> Void
    ) {
        lock.lock()
        pending += archives.count
        lock.unlock()

        for archive in archives {
            queue.async { [weak self] in
                guard let self else { return }
                let result = self.run(archive: archive, mode: mode, compression: compression)
                Task { @MainActor in
                    perItem(archive, result)
                }
                self.finishOne()
                if !self.isBusy {
                    Task { @MainActor in
                        completion()
                    }
                }
            }
        }
    }

    private func finishOne() {
        lock.lock()
        pending -= 1
        lock.unlock()
    }

    private func run(archive: URL, mode: JobMode, compression: CompressionLevel) -> JobResult {
        do {
            let dest: URL
            switch mode {
            case .convertToZip:
                dest = try converter.convertToZip(archive: archive, compression: compression)
            case .extract:
                dest = try converter.extract(archive: archive)
            }
            return .success(dest)
        } catch ConversionError.cancelled {
            return .cancelled
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
