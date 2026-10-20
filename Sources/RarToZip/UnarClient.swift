import Foundation

struct UnarClient {
    private var unarURL: URL { Bundle.main.url(forAuxiliaryExecutable: "unar") ?? bundled("unar") }
    private var lsarURL: URL { Bundle.main.url(forAuxiliaryExecutable: "lsar") ?? bundled("lsar") }

    func passwordWorks(archive: URL, password: String) throws -> Bool {
        let json = try runJSON(tool: lsarURL, arguments: ["-j", "-nr", "-p", password, archive.path])
        if let error = json["lsarError"] as? String {
            let lower = error.lowercased()
            if lower.contains("password") || lower.contains("encrypted") {
                return false
            }
            throw ConversionError.unarFailed(error)
        }
        return true
    }

    func extract(archive: URL, to directory: URL, password: String?, createContainingDirectory: Bool) throws {
        var args = ["-f", "-nq", "-k", "skip"]
        args.append(contentsOf: createContainingDirectory ? ["-d"] : ["-D"])
        args.append(contentsOf: ["-o", directory.path])
        if let password {
            args.append(contentsOf: ["-p", password])
        }
        args.append(archive.path)

        let result = try run(tool: unarURL, arguments: args)
        if result.status != 0 {
            let combined = (result.stdout + "\n" + result.stderr).trimmingCharacters(in: .whitespacesAndNewlines)
            throw ConversionError.unarFailed(combined.isEmpty ? "Không giải nén được file RAR." : combined)
        }
    }

    private func bundled(_ name: String) -> URL {
        Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers", isDirectory: true)
            .appendingPathComponent(name)
    }

    private func runJSON(tool: URL, arguments: [String]) throws -> [String: Any] {
        let result = try run(tool: tool, arguments: arguments)
        let data = Data(result.stdout.utf8)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConversionError.unarFailed("Không đọc được thông tin archive.")
        }
        return json
    }

    private func run(tool: URL, arguments: [String]) throws -> (status: Int32, stdout: String, stderr: String) {
        guard FileManager.default.isExecutableFile(atPath: tool.path) else {
            throw ConversionError.unarFailed("Thiếu bộ giải nén unar trong app.")
        }
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        let stdout = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
