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
            url: "https://github.com/viscan-de/framework-ios-swift-syntax/releases/download/602.0.0/SwiftSyntaxWrapper.xcframework.zip",
            checksum: "5aa50bf256e0a6b9d93cd4f313b1a847e4fabd3804d3b19e7a3b106ea83e867b"
        ),
    ]
)
