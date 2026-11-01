// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LassoText",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "LassoText", targets: ["LassoText"])],
    targets: [
        .target(name: "LassoCore"),
        .target(name: "LassoCapture", dependencies: ["LassoCore"]),
        .target(name: "LassoMenuBar"),
        .executableTarget(name: "LassoText", dependencies: ["LassoCore", "LassoCapture", "LassoMenuBar"]),
        .testTarget(name: "LassoCaptureTests", dependencies: ["LassoCapture"]),
        .testTarget(name: "LassoCoreTests", dependencies: ["LassoCore"]),
        .testTarget(name: "LassoMenuBarTests", dependencies: ["LassoMenuBar"]),
    ]
)
