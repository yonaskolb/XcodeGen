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
        .package(url: "https://github.com/kylef/PathKit.git", .revision("bd899badc81a3424f0e767b8e79f416ffe442248")),
        .package(url: "https://github.com/jpsim/Yams.git", from: "4.0.0"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.2.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "3.0.0"),
        .package(url: "https://github.com/alekkania/XcodeProj.git", .revision("8f6af1428fad1e2d0944a09d9732ba7654424104")),
        .package(url: "https://github.com/jakeheis/SwiftCLI.git", .exact("6.0.3")),
        .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
        .package(url: "https://github.com/SwiftDocOrg/GraphViz.git", from: "0.1.0"),
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
            "Core",
            "GraphViz",
        ]),
        .target(name: "ProjectSpec", dependencies: [
            "JSONUtilities",
            "XcodeProj",
            "Yams",
            "Core",
            "Version",
        ]),
        .target(name: "Core", dependencies: [
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
        .testTarget(name: "CoreTests", dependencies: [
            "Core",
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
