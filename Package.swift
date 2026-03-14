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
            url: "https://github.com/viscan-de/framework-ios-swift-syntax/releases/download/601.0.1/SwiftSyntaxWrapper.xcframework.zip",
            checksum: "06df43a9cae3293297e4bf555b899b721bf3f9877e68657d3cc3b6e5dcd2d446"
        ),
    ]
)
