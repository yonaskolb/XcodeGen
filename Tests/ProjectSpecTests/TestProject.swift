import ProjectSpec
import Foundation
import PathKit
import XcodeProj
import Version

let testProject = Project(
    basePath: Path.current,
    name: "ToJson",
    configs: [
        Config(name: "DevelopmentConfig", type: .debug),
        Config(name: "ProductionConfig", type: .release),
    ],
    targets: [
        Target(
            name: "App",
            type: .application,
            platform: .iOS,
            productName: "App",
            deploymentTarget: Version(major: 0, minor: 1, patch: 2),
            settings: Settings(
                buildSettings: ["foo": "bar"],
                configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                                 configSettings: [:],
                                                 groups: ["config-setting-group"])],
                groups: ["setting-group"]),
            configFiles: ["foo": "bar"],
            sources: [
                TargetSource(
                    path: "Source",
                    name: "Source",
                    compilerFlags: ["-Werror"],
                    excludes: ["foo", "bar"],
                    type: .folder,
                    optional: true,
                    buildPhase: .resources,
                    headerVisibility: .private,
                    createIntermediateGroups: true),
            ],
            dependencies: [
                Dependency(
                    type: .carthage(findFrameworks: true, linkType: .dynamic),
                    reference: "reference",
                    embed: true,
                    codeSign: true,
                    link: true,
                    implicit: true,
                    weakLink: true),
            ],
            info: Plist(path: "info.plist", attributes: ["foo": "bar"]),
            entitlements: Plist(path: "entitlements.plist", attributes: ["foo": "bar"]),
            transitivelyLinkDependencies: true,
            directlyEmbedCarthageDependencies: true,
            requiresObjCLinking: true,
            preBuildScripts: [
                BuildScript(
                    script: .script("pwd"),
                    name: "Foo script",
                    inputFiles: ["foo"],
                    outputFiles: ["bar"],
                    inputFileLists: ["foo.xcfilelist"],
                    outputFileLists: ["bar.xcfilelist"],
                    shell: "/bin/bash",
                    runOnlyWhenInstalling: true,
                    showEnvVars: true,
                    basedOnDependencyAnalysis: false),
            ],
            postCompileScripts: [
                BuildScript(
                    script: .path("cmd.sh"),
                    name: "Bar script",
                    inputFiles: ["foo"],
                    outputFiles: ["bar"],
                    inputFileLists: ["foo.xcfilelist"],
                    outputFileLists: ["bar.xcfilelist"],
                    shell: "/bin/bash",
                    runOnlyWhenInstalling: true,
                    showEnvVars: true,
                    basedOnDependencyAnalysis: false),
            ],
            postBuildScripts: [
                BuildScript(
                    script: .path("cmd.sh"),
                    name: "an another script",
                    inputFiles: ["foo"],
                    outputFiles: ["bar"],
                    inputFileLists: ["foo.xcfilelist"],
                    outputFileLists: ["bar.xcfilelist"],
                    shell: "/bin/bash",
                    runOnlyWhenInstalling: true,
                    showEnvVars: true,
                    basedOnDependencyAnalysis: false),
                BuildScript(
                    script: .path("cmd.sh"),
                    name: "Dependency script",
                    inputFiles: ["foo"],
                    outputFiles: ["bar"],
                    inputFileLists: ["foo.xcfilelist"],
                    outputFileLists: ["bar.xcfilelist"],
                    shell: "/bin/bash",
                    runOnlyWhenInstalling: true,
                    showEnvVars: true,
                    basedOnDependencyAnalysis: true,
                    discoveredDependencyFile: "dep.d"),
            ],
            buildRules: [
                BuildRule(
                    fileType: .pattern("*.xcassets"),
                    action: .script("pre_process_swift.py"),
                    name: "My Build Rule",
                    outputFiles: ["$(SRCROOT)/Generated.swift"],
                    outputFilesCompilerFlags: ["foo"],
                    runOncePerArchitecture: false),
                BuildRule(
                    fileType: .type("sourcecode.swift"),
                    action: .compilerSpec("com.apple.xcode.tools.swift.compiler"),
                    name: nil,
                    outputFiles: ["bar"],
                    outputFilesCompilerFlags: ["foo"],
                    runOncePerArchitecture: true)
            ],
            scheme: TargetScheme(
                testTargets: [
                    Scheme.Test.TestTarget(targetReference: "test target",
                                           randomExecutionOrder: false,
                                           parallelizable: false)
                ],
                configVariants: ["foo"],
                gatherCoverageData: true,
                storeKitConfiguration: "Configuration.storekit",
                disableMainThreadChecker: true,
                stopOnEveryMainThreadCheckerIssue: false,
                commandLineArguments: ["foo": true],
                environmentVariables: [XCScheme.EnvironmentVariable(variable: "environmentVariable",
                                                                    value: "bar",
                                                                    enabled: true)],
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")]),
            legacy: LegacyTarget(
                toolPath: "foo",
                passSettings: true,
                arguments: "bar",
                workingDirectory: "foo"),
            attributes: ["foo": "bar"])],
    aggregateTargets: [
        AggregateTarget(
            name: "aggregate target",
            targets: ["App"],
            settings: Settings(buildSettings: ["buildSettings": "bar"],
                               configSettings: ["configSettings": Settings(buildSettings: [:],
                                                                           configSettings: [:],
                                                                           groups: [])],
                               groups: ["foo"]),
            configFiles: ["configFiles": "bar"],
            buildScripts: [
                BuildScript(
                    script: .path("script"),
                    name: "foo",
                    inputFiles: ["foo"],
                    outputFiles: ["bar"],
                    inputFileLists: ["foo.xcfilelist"],
                    outputFileLists: ["bar.xcfilelist"],
                    shell: "/bin/bash",
                    runOnlyWhenInstalling: true,
                    showEnvVars: false,
                    basedOnDependencyAnalysis: false)
            ],
            scheme: TargetScheme(
                testTargets: [Scheme.Test.TestTarget(targetReference: "test target",
                                                     randomExecutionOrder: false,
                                                     parallelizable: false)],
                configVariants: ["foo"],
                gatherCoverageData: true,
                disableMainThreadChecker: true,
                commandLineArguments: ["foo": true],
                environmentVariables: [XCScheme.EnvironmentVariable(variable: "environmentVariable",
                                                                    value: "bar",
                                                                    enabled: true)],
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")]),
            attributes: ["foo": "bar"])
    ],
    settings: Settings(
        buildSettings: ["foo": "bar"],
        configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                         configSettings: [:],
                                         groups: ["config-setting-group"])],
        groups: ["setting-group"]),
    settingGroups: [
        "foo": Settings(
            buildSettings: ["foo": "bar"],
            configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                             configSettings: [:],
                                             groups: ["config-setting-group"])],
            groups: ["setting-group"])
    ],
    schemes: [
        Scheme(name: "scheme",
               build: Scheme.Build(
                targets: [Scheme.BuildTarget(target: "foo", buildTypes: [.archiving, .analyzing])],
                parallelizeBuild: false,
                buildImplicitDependencies: false,
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")]),
               run: Scheme.Run(
                config: "run config",
                commandLineArguments: ["foo": true],
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")],
                environmentVariables: [XCScheme.EnvironmentVariable(variable: "foo",
                                                                    value: "bar",
                                                                    enabled: false)],
                launchAutomaticallySubstyle: "2",
                storeKitConfiguration: "Configuration.storekit"),
               test: Scheme.Test(
                config: "Config",
                gatherCoverageData: true,
                disableMainThreadChecker: true,
                randomExecutionOrder: false,
                parallelizable: false,
                commandLineArguments: ["foo": true],
                targets: [Scheme.Test.TestTarget(targetReference: "foo",
                                                 randomExecutionOrder: false,
                                                 parallelizable: false)],
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")],
                environmentVariables: [XCScheme.EnvironmentVariable(variable: "foo",
                                                                    value: "bar",
                                                                    enabled: false)]),
               profile: Scheme.Profile(
                config: "profile config",
                commandLineArguments: ["foo": true],
                preActions: [Scheme.ExecutionAction(name: "preAction",
                                                    script: "bar",
                                                    settingsTarget: "foo")],
                postActions: [Scheme.ExecutionAction(name: "postAction",
                                                     script: "bar",
                                                     settingsTarget: "foo")],
                environmentVariables: [XCScheme.EnvironmentVariable(variable: "foo",
                                                                    value: "bar",
                                                                    enabled: false)]),
               analyze: Scheme.Analyze(
                config: "analyze config"),
               archive: Scheme.Archive(
                config: "archive config",
                customArchiveName: "customArchiveName",
                revealArchiveInOrganizer: true,
                preActions: [
                    Scheme.ExecutionAction(
                        name: "preAction",
                        script: "bar",
                        settingsTarget: "foo")
                ],
                postActions: [
                    Scheme.ExecutionAction(
                        name: "postAction",
                        script: "bar",
                        settingsTarget: "foo")
                ]))
    ],
    packages: [
        "Yams": .remote(
            url: "https://github.com/jpsim/Yams",
            versionRequirement: .upToNextMajorVersion("2.0.0")
        ),
    ],
    options: SpecOptions(
        minimumXcodeGenVersion: Version(major: 3, minor: 4, patch: 5),
        carthageBuildPath: "carthageBuildPath",
        carthageExecutablePath: "carthageExecutablePath",
        createIntermediateGroups: true,
        bundleIdPrefix: "bundleIdPrefix",
        settingPresets: .project,
        developmentLanguage: "developmentLanguage",
        indentWidth: 123,
        tabWidth: 456,
        usesTabs: true,
        xcodeVersion: "xcodeVersion",
        deploymentTarget: DeploymentTarget(
            iOS: Version(major: 1, minor: 2, patch: 3),
            tvOS: nil,
            watchOS: Version(major: 4, minor: 5, patch: 6),
            macOS: nil),
        disabledValidations: [.missingConfigFiles],
        defaultConfig: "defaultConfig",
        transitivelyLinkDependencies: true,
        groupSortPosition: .top,
        generateEmptyDirectories: true,
        findCarthageFrameworks: false),
    fileGroups: ["foo", "bar"],
    configFiles: ["configFiles": "bar"],
    attributes: ["attributes": "bar"]
)
