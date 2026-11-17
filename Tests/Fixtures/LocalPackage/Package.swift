// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalPackage",
    products: [
        .library(name: "LocalPackage", targets: [
            "LocalPackage"
        ])
    ],
    targets: [
        .target(name: "LocalPackage"),
        .testTarget(name: "LocalPackageTests", dependencies: [
            "LocalPackage"
        ])
    ]
)
