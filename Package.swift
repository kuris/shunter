// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShortsHunterStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ShortsHunterStudio",
            targets: ["ShortsHunterStudio"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ShortsHunterStudio",
            path: "Sources/ShortsHunterStudio"
        ),
        .testTarget(
            name: "ShortsHunterStudioTests",
            dependencies: ["ShortsHunterStudio"],
            path: "Tests/ShortsHunterStudioTests"
        )
    ]
)
