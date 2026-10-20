import Foundation

enum UniqueURL {
    static func next(in directory: URL, baseName: String, ext: String?) -> URL {
        let fm = FileManager.default
        var index = 0
        while true {
            let name: String
            if index == 0 {
                name = ext.map { "\(baseName).\($0)" } ?? baseName
            } else {
                name = ext.map { "\(baseName) \(index + 1).\($0)" } ?? "\(baseName) \(index + 1)"
            }
            let url = directory.appendingPathComponent(name)
            if !fm.fileExists(atPath: url.path) {
                return url
            }
            index += 1
        }
    }
}
