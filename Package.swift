// swift-tools-version: 5.9
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("DisableOutwardActorInference")
]

let package = Package(
    name: "GazeRow",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GazeRow",
            path: "Sources/GazeRow",
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "GazeRowTests",
            dependencies: ["GazeRow"],
            path: "Tests/GazeRowTests",
            swiftSettings: swiftSettings
        )
    ]
)
