// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "GazeRow",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GazeRow",
            path: "Sources/GazeRow"
        ),
        .testTarget(
            name: "GazeRowTests",
            dependencies: ["GazeRow"],
            path: "Tests/GazeRowTests"
        )
    ]
)
