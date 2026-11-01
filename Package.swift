// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Moffo",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MoffoCore"),
        .executableTarget(name: "Moffo", dependencies: ["MoffoCore"]),
        .testTarget(name: "MoffoCoreTests", dependencies: ["MoffoCore"]),
    ]
)
