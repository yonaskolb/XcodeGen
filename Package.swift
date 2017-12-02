// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "XcodeGen",
    products: [
        .executable(name: "XcodeGen", targets: ["XcodeGen"]),
        .library(name: "XcodeGenKit", targets: ["XcodeGenKit"]),
        .library(name: "ProjectSpec", targets: ["ProjectSpec"]),
        .library(name: "ProjectDescription", type: .dynamic, targets: ["ProjectDescription"])
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.8.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.6.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "0.3.6"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "3.3.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.7.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "2.1.0"),
        .package(url: "https://github.com/xcodeswift/xcproj.git", .revision("ab794ebba7d290f0381a37902e22baa19561e8e5"))
    ],
    targets: [
        .target(name: "XcodeGen", dependencies: [
          "XcodeGenKit",
          "Commander",
          "Rainbow",
        ]),
        .target(name: "XcodeGenKit", dependencies: [
          "ProjectSpec",
          "JSONUtilities",
          "xcproj",
          "PathKit",
        ]),
        .target(name: "ProjectSpec", dependencies: [
          "JSONUtilities",
          "xcproj",
          "Yams",
        ]),
        .target(name: "ProjectDescription", dependencies: []),
        .testTarget(name: "XcodeGenKitTests", dependencies: [
          "XcodeGenKit",
        ])
    ]
)
