// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zero",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Zero", targets: ["Zero"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Zero",
            dependencies: [],
            path: "Sources/Zero"),
        .testTarget(
            name: "ZeroTests",
            dependencies: ["Zero"],
            path: "Tests/ZeroTests"),
    ]
)
