// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexOverlay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexOverlay", targets: ["CodexOverlay"])
    ],
    targets: [
        .executableTarget(
            name: "CodexOverlay",
            path: "Sources/CodexOverlay"
        )
    ]
)
