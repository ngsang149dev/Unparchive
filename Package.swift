// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Unparchive",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Unparchive", targets: ["Unparchive"])
    ],
    targets: [
        .executableTarget(
            name: "Unparchive",
            path: "Sources/Unparchive",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreServices"),
                .linkedFramework("UserNotifications"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
