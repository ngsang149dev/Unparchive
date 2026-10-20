import CoreServices
import Foundation

enum DefaultHandler {
    static func claimIfPossible() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ngsang.Unparchive"
        let types = [
            "com.rarlab.rar-archive",
            "org.nongnu.unar.rar-archive",
            "public.rar-archive"
        ]
        for type in types {
            LSSetDefaultRoleHandlerForContentType(
                type as CFString,
                LSRolesMask.all,
                bundleID as CFString
            )
        }
    }
}
