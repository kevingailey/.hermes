# swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "MyApp",
            targets: ["MyApp"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MyApp",
            path: "Sources/MyApp"
        ),
        .testTarget(
            name: "MyAppTests",
            dependencies: ["MyApp"],
            path: "Tests/MyAppTests"
        ),
    ]
)