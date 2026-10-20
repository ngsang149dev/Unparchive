import Foundation

enum ArchiveURL {
    static func expand(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []
        for url in urls {
            guard let resolved = resolve(url) else { continue }
            let key = resolved.standardizedFileURL.path
            if seen.insert(key).inserted {
                result.append(resolved)
            }
        }
        return result
    }

    private static func resolve(_ url: URL) -> URL? {
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let name = url.lastPathComponent
        let lower = name.lowercased()

        if let match = lower.range(of: #"\.part(\d+)\.rar$"#, options: .regularExpression) {
            let digits = String(lower[match]).dropFirst(5).dropLast(4)
            if Int(digits) != 1 {
                if let first = firstVolume(from: url, partDigits: digits.count) {
                    return first
                }
            }
            return url
        }

        if let match = lower.range(of: #"\.r(\d{2,})$"#, options: .regularExpression) {
            let num = Int(String(lower[match]).dropFirst(2)) ?? 0
            if num > 0 {
                let base = String(name.dropLast(4))
                let rar = url.deletingLastPathComponent().appendingPathComponent(base + ".rar")
                if FileManager.default.fileExists(atPath: rar.path) { return rar }
                let r00 = url.deletingLastPathComponent().appendingPathComponent(base + ".r00")
                if FileManager.default.fileExists(atPath: r00.path) { return r00 }
            }
        }

        let ext = url.pathExtension.lowercased()
        guard ext == "rar" || ext == "cbr" || lower.hasSuffix(".r00") else { return nil }
        return url
    }

    private static func firstVolume(from url: URL, partDigits: Int) -> URL? {
        let name = url.lastPathComponent
        guard let regex = try? NSRegularExpression(pattern: #"\.part\d+\.rar$"#, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        let padded = String(format: "%0\(partDigits)d", 1)
        let firstName = regex.stringByReplacingMatches(in: name, range: range, withTemplate: ".part\(padded).rar")
        let first = url.deletingLastPathComponent().appendingPathComponent(firstName)
        return FileManager.default.fileExists(atPath: first.path) ? first : nil
    }
}
