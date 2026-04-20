// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MDMath",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "MDMath",
            targets: ["MDMath"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.0")
    ],
    targets: [
        .target(
            name: "MDMath",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MDMathTests",
            dependencies: ["MDMath"]
        )
    ],
    swiftLanguageModes: [.v6]
)
