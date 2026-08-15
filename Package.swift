// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeBuddy",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeBuddy",
            path: "Sources/ClaudeBuddy"
        )
    ]
)
