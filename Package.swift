// swift-tools-version:5.0

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
        .package(url: "https://github.com/jpsim/Yams.git", from: "1.0.0"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.1.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
        .package(url: "https://github.com/tuist/xcodeproj.git", .exact("6.4.0")),
        .package(url: "https://github.com/jakeheis/SwiftCLI.git", from: "5.2.0"),
    ],
    targets: [
        .target(name: "XcodeGen", dependencies: [
            "XcodeGenCLI",
        ]),
        .target(name: "XcodeGenCLI", dependencies: [
            "XcodeGenKit",
            "ProjectSpec",
            "SwiftCLI",
            "Rainbow",
            "PathKit",
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
            "Spectre",
            "PathKit",
        ]),
        .testTarget(name: "PerformanceTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
        ]),
    ]
)
