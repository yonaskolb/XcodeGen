// swift-tools-version:5.9

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
            .product(name: "Version", package: "Version"),
        ]),
        .target(name: "XcodeGenCLI", dependencies: [
            "XcodeGenKit",
            "ProjectSpec",
            .product(name: "SwiftCLI", package: "SwiftCLI"),
            .product(name: "Rainbow", package: "Rainbow"),
            .product(name: "PathKit", package: "PathKit"),
            .product(name: "Version", package: "Version"),
        ]),
        .target(name: "XcodeGenKit", dependencies: [
            "ProjectSpec",
            .product(name: "JSONUtilities", package: "JSONUtilities"),
            .product(name: "XcodeProj", package: "XcodeProj"),
            .product(name: "PathKit", package: "PathKit"),
            "XcodeGenCore",
        ], resources: [
            .copy("SettingPresets")
        ]),
        .target(name: "ProjectSpec", dependencies: [
            .product(name: "JSONUtilities", package: "JSONUtilities"),
            .product(name: "XcodeProj", package: "XcodeProj"),
            .product(name: "Yams", package: "yams"),
            "XcodeGenCore",
            .product(name: "Version", package: "Version"),
        ]),
        .target(name: "XcodeGenCore", dependencies: [
            .product(name: "PathKit", package: "PathKit"),
            .product(name: "Yams", package: "yams"),
        ]),
        .target(name: "TestSupport", dependencies: [
            .product(name: "XcodeProj", package: "XcodeProj"),
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
        ]),
        .testTarget(name: "XcodeGenKitTests", dependencies: [
            "XcodeGenKit",
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
            "TestSupport",
        ]),
        .testTarget(name: "FixtureTests", dependencies: [
            "XcodeGenKit",
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
            "TestSupport",
        ]),
        .testTarget(name: "XcodeGenCoreTests", dependencies: [
            "XcodeGenCore",
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
            "TestSupport",
        ]),
        .testTarget(name: "ProjectSpecTests", dependencies: [
            "ProjectSpec",
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
            "TestSupport",
        ]),
        .testTarget(name: "PerformanceTests", dependencies: [
            "XcodeGenKit",
            .product(name: "Spectre", package: "Spectre"),
            .product(name: "PathKit", package: "PathKit"),
            "TestSupport",
        ]),
    ]
)
