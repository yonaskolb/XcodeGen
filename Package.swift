// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "XcodeGen",
    targets: [
        Target(name: "XcodeGen", dependencies: ["XcodeGenKit"]),
        Target(name: "XcodeGenKit", dependencies: ["ProjectSpec"]),
        Target(name: "ProjectSpec"),
    ],
    dependencies: [
        .Package(url: "https://github.com/kylef/PathKit.git", majorVersion: 0, minor: 8),
        .Package(url: "https://github.com/kylef/Commander.git", majorVersion: 0, minor: 6),
        .Package(url: "https://github.com/jpsim/Yams.git", majorVersion: 0, minor: 3),
        .Package(url: "https://github.com/yonaskolb/JSONUtilities.git", majorVersion: 3, minor: 3),
        .Package(url: "https://github.com/kylef/Spectre.git", majorVersion: 0, minor: 7),
        .Package(url: "https://github.com/onevcat/Rainbow", majorVersion: 2),
        .Package(url: "https://github.com/carambalabs/xcodeproj.git", majorVersion: 0, minor: 1),
    ]
)
