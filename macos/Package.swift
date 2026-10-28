// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bordbar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Bordbar", path: "Sources/Bordbar")
    ]
)
