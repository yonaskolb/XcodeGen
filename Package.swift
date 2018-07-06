// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "XcodeGen",
    products: [
        .executable(name: "xcodegen", targets: ["XcodeGen"]),
        .library(name: "XcodeGenKit", targets: ["XcodeGenKit"]),
        .library(name: "ProjectSpec", targets: ["ProjectSpec"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/PathKit.git", from: "0.9.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.8.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "0.3.6"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.0.0"),
        .package(url: "https://github.com/yonaskolb/Spectre.git", from: "0.8.1"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
        .package(url: "https://github.com/xcode-project-manager/xcodeproj.git", from: "4.3.0")
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
          "xcodeproj",
          "PathKit",
        ]),
        .target(name: "ProjectSpec", dependencies: [
          "JSONUtilities",
          "xcodeproj",
          "Yams",
        ]),
        .testTarget(name: "XcodeGenKitTests", dependencies: [
          "XcodeGenKit",
          "Spectre"
        ])
    ]
)
