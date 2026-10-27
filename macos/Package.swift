// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IceBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "IceBar", path: "Sources/IceBar")
    ]
)
