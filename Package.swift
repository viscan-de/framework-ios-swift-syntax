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
            checksum: "a106e636cab03c26a7739fa1905584bce477f968b75eb1871491eea4ed3e0fd8"
        ),
    ]
)
