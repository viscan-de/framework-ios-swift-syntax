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
            checksum: "27408bb49587f80273de10b8b7827b1356765d0952aad5083f6a61c6a5df1361"
        ),
    ]
)
