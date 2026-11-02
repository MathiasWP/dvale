// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StillBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "StillBar", targets: ["StillBar"])],
    targets: [
        .target(name: "StillBarCore"),
        .executableTarget(name: "StillBar", dependencies: ["StillBarCore"]),
        .testTarget(name: "StillBarCoreTests", dependencies: ["StillBarCore"])
    ]
)
