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
            checksum: "c4ff3be64d2d3fae5c08d674fcd85385fb8dff96623235ad71fdde03046b1251"
        ),
    ]
)
