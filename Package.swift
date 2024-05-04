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
            checksum: "e9e17db202a8698a965f49749ed148af51a377e7eba7f87379b192e422089e05"
        ),
    ]
)
