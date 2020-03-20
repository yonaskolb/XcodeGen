import Foundation
import PathKit
import ProjectSpec
import XcodeProj

extension Project {

    static func testProject(basePath: Path, createSources: Bool = true) throws -> Project {

        if createSources {
            try? basePath.delete()
            try basePath.mkpath()
        }

        var paths: [Path] = []
        var targets: [Target] = []
        let scheme = TargetScheme(
            testTargets: [],
            configVariants: ["Test", "Staging", "Prod"],
            gatherCoverageData: true,
            disableMainThreadChecker: true,
            stopOnEveryMainThreadCheckerIssue: false,
            commandLineArguments: [
                "--command": true,
                "--command2": false,
            ],
            environmentVariables: [
                XCScheme.EnvironmentVariable(variable: "ENV", value: "HELLO", enabled: true),
                XCScheme.EnvironmentVariable(variable: "ENV2", value: "HELLO", enabled: false),
            ],
            preActions: [Scheme.ExecutionAction(name: "run", script: "script")],
            postActions: [Scheme.ExecutionAction(name: "run", script: "script")]
        )
        for platform in Platform.allCases {
            let appTarget = Target(
                name: "App_\(platform)",
                type: .application,
                platform: platform,
                sources: [TargetSource(path: "App_\(platform)")],
                dependencies: [
                    Dependency(type: .target, reference: "Framework_\(platform)"),
                    Dependency(type: .target, reference: "Framework2_\(platform)"),
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire"),
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "BrightFutures"),
                ],
                scheme: scheme
            )
            targets.append(appTarget)
            if createSources {
                paths += try createTargetSources(path: basePath, target: appTarget)
            }

            let testTarget = Target(
                name: "App_Test_\(platform)",
                type: .unitTestBundle,
                platform: platform,
                sources: [TargetSource(path: "App_Test_\(platform)")],
                dependencies: [
                    Dependency(type: .target, reference: "App_\(platform)"),
                    Dependency(type: .target, reference: "Framework_\(platform)"),
                    Dependency(type: .target, reference: "Framework2_\(platform)"),
                ],
                scheme: scheme
            )
            targets.append(testTarget)
            if createSources {
                paths += try createTargetSources(path: basePath, target: testTarget)
            }

            let frameworkTarget = Target(
                name: "Framework_\(platform)",
                type: .framework,
                platform: platform,
                sources: [
                    TargetSource(path: "Framework_\(platform)"),
                ],
                dependencies: [
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire"),
                ],
                scheme: scheme
            )
            targets.append(frameworkTarget)
            if createSources {
                paths += try createTargetSources(path: basePath, target: frameworkTarget)
            }

            let frameworkTarget2 = Target(
                name: "Framework2_\(platform)",
                type: .framework,
                platform: platform,
                sources: [TargetSource(path: "Framework2_\(platform)")],
                dependencies: [
                    Dependency(type: .target, reference: "Framework_\(platform)"),
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire"),
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "BrightFutures"),
                ],
                scheme: scheme
            )
            targets.append(frameworkTarget2)
            if createSources {
                paths += try createTargetSources(path: basePath, target: frameworkTarget2)
            }
        }
        if createSources {
            let files = paths.filter { $0.isFile }
            let directories = paths.filter { $0.isDirectory }
            print("Generated \(files.count) files and \(directories.count) directories")
        }

        return Project(
            basePath: basePath,
            name: "Project",
            configs: [
                Config(name: "Debug Test", type: .debug),
                Config(name: "Release Test", type: .release),
                Config(name: "Debug Staging", type: .debug),
                Config(name: "Release Staging", type: .release),
                Config(name: "Debug Production", type: .debug),
                Config(name: "Release Production", type: .release),
            ],
            targets: targets,
            aggregateTargets: [],
            settings: [:],
            settingGroups: [:],
            schemes: [],
            options: SpecOptions(),
            fileGroups: [],
            configFiles: [:],
            attributes: [:]
        )
    }

    fileprivate static func createTargetSources(path: Path, target: Target) throws -> [Path] {
        let levels = 3
        let directoriesPerLevel = 1
        let swiftFilesPerDirectory = 5
        let objFilesPerDirectory = 2
        let resourcesPerDirectory = 2
        var paths: [Path] = []

        func createDirectory(_ path: Path, depth: Int = 0) throws {
            try path.mkpath()
            paths.append(path)

            for swiftFile in 1...swiftFilesPerDirectory {
                let file = path + "file_\(swiftFile).swift"
                try file.write("")
                paths.append(file)
            }

            for resourceFile in 1...resourcesPerDirectory {
                let file = path + "file_\(resourceFile).png"
                try file.write("")
                paths.append(file)
            }

            for objFile in 1...objFilesPerDirectory {
                let header = path + "file_\(objFile).h"
                try header.write("")
                paths.append(header)

                let implementation = path + "file_\(objFile).m"
                try implementation.write("")
                paths.append(implementation)
            }

            if depth < levels - 1 {
                for directory in 1...directoriesPerLevel {
                    try createDirectory(path + "directory_\(directory)", depth: depth + 1)
                }
            }
        }

        for source in target.sources {
            try createDirectory(path + source.path)
        }
        return paths
    }
}
