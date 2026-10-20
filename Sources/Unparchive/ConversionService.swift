import Foundation

enum CompressionLevel: Sendable {
    case fast   // store — fast, no re-compression (RAR contents are usually already compressed)
    case small  // deflate — smaller output, slower
}

enum ConversionError: LocalizedError {
    case cancelled
    case emptyArchive
    case unarFailed(String)
    case zipFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Đã huỷ."
        case .emptyArchive:
            return "Archive không có nội dung."
        case .unarFailed(let message):
            return message
        case .zipFailed(let message):
            return message
        }
    }
}

struct ConversionService {
    private let unrar = UnrarClient()
    private let unar = UnarClient()

    func convertToZip(
        archive: URL,
        outputDirectory: URL? = nil,
        outputName: String? = nil,
        compression: CompressionLevel = .fast
    ) throws -> URL {
        let temp = try FileManager.default.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: archive,
            create: true
        )
        defer { try? FileManager.default.removeItem(at: temp) }

        try performExtraction(archive: archive, to: temp)
        try ensureNotEmpty(temp)

        let directory = outputDirectory ?? archive.deletingLastPathComponent()
        let name = outputName ?? archive.deletingPathExtension().lastPathComponent
        let dest = UniqueURL.next(in: directory, baseName: name, ext: "zip")
        try zipContents(of: temp, to: dest, compression: compression)
        return dest
    }

    func extract(
        archive: URL,
        outputDirectory: URL? = nil,
        outputName: String? = nil
    ) throws -> URL {
        let directory = outputDirectory ?? archive.deletingLastPathComponent()
        let name = outputName ?? archive.deletingPathExtension().lastPathComponent
        let dest = UniqueURL.next(in: directory, baseName: name, ext: nil)

        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        do {
            try performExtraction(archive: archive, to: dest)
            try ensureNotEmpty(dest)
            return dest
        } catch {
            try? FileManager.default.removeItem(at: dest)
            throw error
        }
    }

    // MARK: - Extraction (unrar fast path → unar fallback)

    private func performExtraction(archive: URL, to directory: URL) throws {
        switch unrar.extract(archive: archive, to: directory, password: nil) {
        case .success:
            return
        case .wrongPassword:
            let password = try promptUntilValid(archive: archive)
            switch unrar.extract(archive: archive, to: directory, password: password) {
            case .success:
                return
            case .wrongPassword:
                throw ConversionError.unarFailed("Mật khẩu không đúng.")
            case .failure(let message):
                throw ConversionError.unarFailed(message)
            }
        case .failure:
            // unrar could not handle it — fall back to unar.
            try extractWithUnar(archive: archive, to: directory)
        }
    }

    private func extractWithUnar(archive: URL, to directory: URL) throws {
        do {
            try unar.extract(archive: archive, to: directory, password: nil, createContainingDirectory: false)
        } catch ConversionError.unarFailed(let message) where Self.isPasswordError(message) {
            let password = try promptUntilValid(archive: archive)
            try unar.extract(archive: archive, to: directory, password: password, createContainingDirectory: false)
        }
    }

    private static func isPasswordError(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("password") || lower.contains("encrypted")
    }

    private func promptUntilValid(archive: URL) throws -> String {
        var lastError: String?
        for _ in 0..<4 {
            let password = PasswordPrompt.ask(
                archiveName: archive.lastPathComponent,
                retryMessage: lastError
            )
            guard let password else { throw ConversionError.cancelled }
            if try unar.passwordWorks(archive: archive, password: password) {
                return password
            }
            lastError = "Mật khẩu không đúng. Thử lại."
        }
        throw ConversionError.unarFailed("Sai mật khẩu quá nhiều lần.")
    }

    // MARK: - Helpers

    private func ensureNotEmpty(_ dir: URL) throws {
        let items = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        if items.isEmpty {
            throw ConversionError.emptyArchive
        }
    }

    private func zipContents(of directory: URL, to dest: URL, compression: CompressionLevel) throws {
        switch compression {
        case .fast:
            try runProcess(
                executable: "/usr/bin/zip",
                arguments: ["-q", "-r", "-0", "-X", dest.path, "."],
                directory: directory,
                fallbackMessage: "Không tạo được file ZIP."
            )
        case .small:
            try runProcess(
                executable: "/usr/bin/ditto",
                arguments: ["-c", "-k", "--norsrc", "--noextattr", ".", dest.path],
                directory: directory,
                fallbackMessage: "Không tạo được file ZIP."
            )
        }
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        directory: URL,
        fallbackMessage: String
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let err = Pipe()
        process.standardError = err
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ConversionError.zipFailed(message.isEmpty ? fallbackMessage : message)
        }
    }
}
