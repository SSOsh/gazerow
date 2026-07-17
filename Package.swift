// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gazerow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "gazerow", targets: ["GazeRow"])
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
