// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MDMath",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MDMath",
            targets: ["MDMath"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3"),
        .package(url: "https://github.com/gradpath-app/LaTeXSwiftUI.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MDMath",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "LaTeXSwiftUI", package: "LaTeXSwiftUI"),
            ]
        ),
        .testTarget(
            name: "MDMathTests",
            dependencies: ["MDMath"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
