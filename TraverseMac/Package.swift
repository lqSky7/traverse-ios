// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TraverseMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TraverseMac", targets: ["TraverseMac"])
    ],
    targets: [
        .executableTarget(
            name: "TraverseMac",
            path: "Sources/TraverseMac",
            resources: []
        )
    ]
)
