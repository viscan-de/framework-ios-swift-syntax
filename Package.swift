// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftSyntaxWrapper",
    products: [
        .library(name: "SwiftSyntaxWrapper", targets: ["SwiftSyntaxWrapper"]),
    ],
    targets: [
        .binaryTarget(
            name: "SwiftSyntaxWrapper",
            url: "https://github.com/vigram-sw/framework-ios-swift-syntax/releases/download/510.0.1/SwiftSyntaxWrapper.xcframework.zip",
            checksum: "8d7ac243c91040c488b487d3a2262dc3cb39c908d9a04be2822c837e9798c65d"
        ),
    ]
)
