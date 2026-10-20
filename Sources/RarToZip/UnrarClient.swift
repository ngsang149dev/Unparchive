import Foundation

/// RARLAB unrar — the fast, reference RAR extractor (RAR1–RAR5).
/// Primary engine; `UnarClient` remains the fallback.
struct UnrarClient {

    enum Outcome: Equatable {
        case success
        case wrongPassword
        case failure(String)
    }

    private var unrarURL: URL {
        Bundle.main.url(forAuxiliaryExecutable: "unrar") ?? Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers", isDirectory: true)
            .appendingPathComponent("unrar")
    }

    /// Extracts `archive` into `directory` (created by the caller).
    /// `password == nil` disables the interactive prompt via `-p-`.
    func extract(archive: URL, to directory: URL, password: String?) -> Outcome {
        var args = ["x", "-y", "-o+", "-idq"]
        if let password {
            args.append("-p\(password)")
        } else {
            args.append("-p-")
        }
        args.append(archive.path)
        args.append(directory.path + "/")

        let result = run(args)
        if result.status == 0 {
            return .success
        }
        let message = (result.stdout + "\n" + result.stderr)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // unrar CLI exit code 11 = incorrect/missing password.
        if result.status == 11 {
            return .wrongPassword
        }
        return .failure(message.isEmpty ? "Không giải nén được (mã lỗi \(result.status))." : message)
    }

    private func run(_ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        guard FileManager.default.isExecutableFile(atPath: unrarURL.path) else {
            return (-1, "", "Thiếu bộ giải nén unrar trong app.")
        }
        let process = Process()
        process.executableURL = unrarURL
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try? process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
