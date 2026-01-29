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
    dependencies: [
        .package(url: "https://github.com/CodeEditApp/CodeEditTextView.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Zero",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView")
            ],
            path: "Sources/Zero",
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "ZeroTests",
            dependencies: ["Zero"],
            path: "Tests/ZeroTests"),
    ]
)
