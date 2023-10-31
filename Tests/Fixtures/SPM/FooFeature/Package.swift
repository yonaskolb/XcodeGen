// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FooFeature",
    products: [
        .library(name: "FooDomain", targets: [
            "FooDomain"
        ]),
        .library(name: "FooUI", targets: [
            "FooUI"
        ])
    ],
    targets: [
        .target(name: "FooDomain"),
        .target(name: "FooUI")
    ]
)
