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
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.1")
    ],
    targets: [
        .executableTarget(
            name: "CodexOverlay",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/CodexOverlay"
        )
    ]
)
