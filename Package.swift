// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "XcodeGen",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "xcodegen", targets: ["XcodeGen"]),
        .library(name: "XcodeGenKit", targets: ["XcodeGenKit"]),
        .library(name: "ProjectSpec", targets: ["ProjectSpec"]),
    ],
    dependencies: [
        .package(url: "https://github.com/kylef/PathKit.git", from: "1.0.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.0"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.2.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.9.2"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.7.0"),
        .package(url: "https://github.com/jakeheis/SwiftCLI.git", from: "6.0.3"),
        .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
        .package(url: "https://github.com/SwiftDocOrg/GraphViz.git", .exact("0.2.0")),
    ],
    targets: [
        .target(name: "XcodeGen", dependencies: [
            "XcodeGenCLI",
            "Version",
        ]),
        .target(name: "XcodeGenCLI", dependencies: [
            "XcodeGenKit",
            "ProjectSpec",
            "SwiftCLI",
            "Rainbow",
            "PathKit",
            "Version",
        ]),
        .target(name: "XcodeGenKit", dependencies: [
            "ProjectSpec",
            "JSONUtilities",
            "XcodeProj",
            "PathKit",
            "XcodeGenCore",
            "GraphViz",
        ]),
        .target(name: "ProjectSpec", dependencies: [
            "JSONUtilities",
            "XcodeProj",
            "Yams",
            "XcodeGenCore",
            "Version",
        ]),
        .target(name: "XcodeGenCore", dependencies: [
            "PathKit",
            "Yams",
        ]),
        .target(name: "TestSupport", dependencies: [
            "XcodeProj",
            "Spectre",
            "PathKit",
        ]),
        .testTarget(name: "XcodeGenKitTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ]),
        .testTarget(name: "FixtureTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ]),
        .testTarget(name: "XcodeGenCoreTests", dependencies: [
            "XcodeGenCore",
            "Spectre",
            "PathKit",
            "TestSupport",
        ]),
        .testTarget(name: "ProjectSpecTests", dependencies: [
            "ProjectSpec",
            "Spectre",
            "PathKit",
            "TestSupport",
        ]),
        .testTarget(name: "PerformanceTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ]),
    ]
)
