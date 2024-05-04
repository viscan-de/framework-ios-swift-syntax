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
            checksum: "16b0aea6513c6e12d1ef98b73b679db7243ca8453875598d7cff08081fe1d6e2"
        ),
    ]
)
