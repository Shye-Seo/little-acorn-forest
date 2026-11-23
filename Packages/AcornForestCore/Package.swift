// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AcornForestCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AcornForestCore", targets: ["AcornForestCore"])
    ],
    targets: [
        .target(
            name: "AcornForestCore",
            path: "Sources/AcornForestCore"
        ),
        .testTarget(
            name: "AcornForestCoreTests",
            dependencies: ["AcornForestCore"],
            path: "Tests/AcornForestCoreTests"
        )
    ]
)
