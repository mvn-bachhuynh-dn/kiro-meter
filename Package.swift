// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiroMeter",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "KiroMeter",
            path: "Sources/KiroMeter",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "KiroMeterTests",
            dependencies: ["KiroMeter"],
            path: "Tests/KiroMeterTests"
        ),
    ]
)
