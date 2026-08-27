// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "DevServerActivity",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DevServerActivity", targets: ["DevServerActivity"]),
        .library(name: "DevServerActivityCore", targets: ["DevServerActivityCore"])
    ],
    targets: [
        .executableTarget(
            name: "DevServerActivity",
            dependencies: ["DevServerActivityCore"],
            path: "Sources/DevServerActivity"
        ),
        .target(
            name: "DevServerActivityCore",
            path: "Sources/DevServerActivityCore"
        ),
        .testTarget(
            name: "DevServerActivityCoreTests",
            dependencies: ["DevServerActivityCore"],
            path: "Tests/DevServerActivityCoreTests"
        )
    ]
)
