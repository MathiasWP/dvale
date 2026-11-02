// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dvale",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "dvale", targets: ["dvale"])],
    targets: [
        .target(name: "DvaleCore"),
        .executableTarget(name: "dvale", dependencies: ["DvaleCore"]),
        .testTarget(name: "DvaleCoreTests", dependencies: ["DvaleCore"])
    ]
)
