// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RarToZip",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "RarToZip", targets: ["RarToZip"])
    ],
    targets: [
        .executableTarget(
            name: "RarToZip",
            path: "Sources/RarToZip",
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
