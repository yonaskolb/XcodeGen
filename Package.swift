// swift-tools-version:5.7

import PackageDescription

func swiftSettings() -> [SwiftSetting] {
    return [
        .define("FOUNDATION_FRAMEWORK", .when(platforms: [.linux])),
    ]
}

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
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/yonaskolb/JSONUtilities.git", from: "4.2.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.9.2"),
        .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", exact: "8.16.0"),
        .package(url: "https://github.com/jakeheis/SwiftCLI.git", from: "6.0.3"),
        .package(url: "https://github.com/mxcl/Version", from: "2.0.0"),
        .package(url: "https://github.com/freddi-kit/ArtifactBundleGen", exact: "0.0.6")
    ],
    targets: [
        .executableTarget(name: "XcodeGen", dependencies: [
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
        ], swiftSettings: swiftSettings()),
        .target(name: "XcodeGenKit", dependencies: [
            "ProjectSpec",
            "JSONUtilities",
            "XcodeProj",
            "PathKit",
            "XcodeGenCore",
        ], resources: [
            .copy("SettingPresets")
        ], swiftSettings: swiftSettings()),
        .target(name: "ProjectSpec", dependencies: [
            "JSONUtilities",
            "XcodeProj",
            "Yams",
            "XcodeGenCore",
            "Version",
        ], swiftSettings: swiftSettings()),
        .target(name: "XcodeGenCore", dependencies: [
            "PathKit",
            "Yams",
        ], swiftSettings: swiftSettings()),
        .target(name: "TestSupport", dependencies: [
            "XcodeProj",
            "Spectre",
            "PathKit",
        ], swiftSettings: swiftSettings()),
        .testTarget(name: "XcodeGenKitTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ], swiftSettings: swiftSettings()),
        .testTarget(name: "FixtureTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ], swiftSettings: swiftSettings()),
        .testTarget(name: "XcodeGenCoreTests", dependencies: [
            "XcodeGenCore",
            "Spectre",
            "PathKit",
            "TestSupport",
        ], swiftSettings: swiftSettings()),
        .testTarget(name: "ProjectSpecTests", dependencies: [
            "ProjectSpec",
            "Spectre",
            "PathKit",
            "TestSupport",
        ], swiftSettings: swiftSettings()),
        .testTarget(name: "PerformanceTests", dependencies: [
            "XcodeGenKit",
            "Spectre",
            "PathKit",
            "TestSupport",
        ], swiftSettings: swiftSettings()),
    ]
)
