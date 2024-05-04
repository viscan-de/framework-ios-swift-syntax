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
            url: "https://github.com/vigram-sw/framework-ios-swift-syntax/releases/download/509.0.2/SwiftSyntaxWrapper.xcframework.zip",
            checksum: "0838e117bca173ac67b15220e20e7122a7709ef62414124112434c732392f8d1"
        ),
    ]
)
