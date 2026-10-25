// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LassoText",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "LassoText", targets: ["LassoText"])],
    targets: [
        .target(name: "LassoCore"),
        .executableTarget(name: "LassoText", dependencies: ["LassoCore"]),
        .testTarget(name: "LassoCoreTests", dependencies: ["LassoCore"]),
    ]
)
