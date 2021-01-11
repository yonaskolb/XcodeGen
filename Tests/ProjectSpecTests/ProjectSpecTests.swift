import PathKit
import ProjectSpec
import Spectre
import XcodeProj
import XCTest
import TestSupport
import Version

class ProjectSpecTests: XCTestCase {

    func testTargetType() {
        describe {

            let framework = Target(
                name: "MyFramework",
                type: .framework,
                platform: .iOS,
                settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
            )
            let staticLibrary = Target(
                name: "MyStaticLibrary",
                type: .staticLibrary,
                platform: .iOS,
                settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
            )
            let dynamicLibrary = Target(
                name: "MyDynamicLibrary",
                type: .dynamicLibrary,
                platform: .iOS,
                settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
            )
            $0.it("is a framework when it has the right extension") {
                try expect(framework.type.isFramework).to.beTrue()
            }

            $0.it("is a library when it has the right type") {
                try expect(staticLibrary.type.isLibrary).to.beTrue()
                try expect(dynamicLibrary.type.isLibrary).to.beTrue()
            }
        }
    }

    func testTargetFilename() {
        describe {

            let framework = Target(
                name: "MyFramework",
                type: .framework,
                platform: .iOS,
                settings: Settings(buildSettings: [:])
            )
            let staticLibrary = Target(
                name: "MyStaticLibrary",
                type: .staticLibrary,
                platform: .iOS,
                settings: Settings(buildSettings: [:])
            )
            let dynamicLibrary = Target(
                name: "MyDynamicLibrary",
                type: .dynamicLibrary,
                platform: .iOS,
                settings: Settings(buildSettings: [:])
            )
            $0.it("has correct filename") {
                try expect(framework.filename) == "MyFramework.framework"
                try expect(staticLibrary.filename) == "libMyStaticLibrary.a"
                try expect(dynamicLibrary.filename) == "MyDynamicLibrary.dylib"
            }
        }
    }

    func testDeploymentTarget() {
        describe {

            $0.it("has correct build setting") {
                try expect(Platform.iOS.deploymentTargetSetting) == "IPHONEOS_DEPLOYMENT_TARGET"
                try expect(Platform.tvOS.deploymentTargetSetting) == "TVOS_DEPLOYMENT_TARGET"
                try expect(Platform.watchOS.deploymentTargetSetting) == "WATCHOS_DEPLOYMENT_TARGET"
                try expect(Platform.macOS.deploymentTargetSetting) == "MACOSX_DEPLOYMENT_TARGET"
            }

            $0.it("parses version correctly") {
                try expect(Version.parse("2").deploymentTarget) == "2.0"
                try expect(Version.parse("2.0").deploymentTarget) == "2.0"
                try expect(Version.parse("2.1").deploymentTarget) == "2.1"
                try expect(Version.parse("2.10").deploymentTarget) == "2.10"
                try expect(Version.parse("2.1.0").deploymentTarget) == "2.1"
                try expect(Version.parse("2.12.0").deploymentTarget) == "2.12"
                try expect(Version.parse("2.1.2").deploymentTarget) == "2.1.2"
                try expect(Version.parse("2.10.2").deploymentTarget) == "2.10.2"
                try expect(Version.parse("2.0.2").deploymentTarget) == "2.0.2"
                try expect(Version.parse(2).deploymentTarget) == "2.0"
                try expect(Version.parse(2.0).deploymentTarget) == "2.0"
                try expect(Version.parse(2.1).deploymentTarget) == "2.1"
            }
        }
    }

    func testValidation() {
        describe {

            let baseProject = Project(name: "", configs: [Config(name: "invalid")])
            let invalidSettings = Settings(
                configSettings: ["invalidConfig": [:]],
                groups: ["invalidSettingGroup"]
            )

            $0.it("fails with invalid XcodeGen version") {
                let minimumVersion = try Version.parse("1.11.1")
                var project = baseProject
                project.options = SpecOptions(minimumXcodeGenVersion: minimumVersion)

                func expectMinimumXcodeGenVersionError(_ project: Project, minimumVersion: Version, xcodeGenVersion: Version, file: String = #file, line: Int = #line) throws {
                    try expectError(SpecValidationError(errors: [SpecValidationError.ValidationError.invalidXcodeGenVersion(minimumVersion: minimumVersion, version: xcodeGenVersion)]), file: file, line: line) {
                        try project.validateMinimumXcodeGenVersion(xcodeGenVersion)
                    }
                }

                try expectMinimumXcodeGenVersionError(project, minimumVersion: minimumVersion, xcodeGenVersion: Version.parse("1.11.0"))
                try expectMinimumXcodeGenVersionError(project, minimumVersion: minimumVersion, xcodeGenVersion: Version.parse("1.10.99"))
                try expectMinimumXcodeGenVersionError(project, minimumVersion: minimumVersion, xcodeGenVersion: Version.parse("0.99"))
            }

            $0.it("fails with invalid project") {
                var project = baseProject
                project.settings = invalidSettings
                project.configFiles = ["invalidConfig": "invalidConfigFile"]
                project.fileGroups = ["invalidFileGroup"]
                project.packages = ["invalidLocalPackage": .local(path: "invalidLocalPackage")]
                project.settingGroups = ["settingGroup1": Settings(
                    configSettings: ["invalidSettingGroupConfig": [:]],
                    groups: ["invalidSettingGroupSettingGroup"]
                )]

                try expectValidationError(project, .invalidConfigFileConfig("invalidConfig"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(project, .invalidConfigFile(configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(project, .invalidFileGroup("invalidFileGroup"))
                try expectValidationError(project, .invalidLocalPackage("invalidLocalPackage"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroupSettingGroup"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidSettingGroupConfig"))
            }

            $0.it("allows non-existent configurations") {
                var project = baseProject
                project.options = SpecOptions(disabledValidations: [.missingConfigs])
                let configPath = fixturePath + "test.xcconfig"
                project.configFiles = ["missingConfiguration": configPath.string]
                try project.validate()
            }

            $0.it("allows non-existent config files") {
                var project = baseProject
                project.options = SpecOptions(disabledValidations: [.missingConfigFiles])
                project.configFiles = ["invalid": "doesntexist.xcconfig"]
                try project.validate()
            }

            $0.it("fails with invalid target") {
                var project = baseProject
                project.targets = [Target(
                    name: "target1",
                    type: .application,
                    platform: .iOS,
                    settings: invalidSettings,
                    configFiles: ["invalidConfig": "invalidConfigFile"],
                    sources: ["invalidSource"],
                    dependencies: [
                        Dependency(type: .target, reference: "invalidDependency"),
                        Dependency(type: .package(product: nil), reference: "invalidPackage"),
                    ],
                    preBuildScripts: [BuildScript(script: .path("invalidPreBuildScript"), name: "preBuildScript1")],
                    postCompileScripts: [BuildScript(script: .path("invalidPostCompileScript"))],
                    postBuildScripts: [BuildScript(script: .path("invalidPostBuildScript"))],
                    scheme: TargetScheme(testTargets: ["invalidTarget"])
                )]

                try expectValidationError(project, .invalidTargetDependency(target: "target1", dependency: "invalidDependency"))
                try expectValidationError(project, .invalidSwiftPackage(name: "invalidPackage", target: "target1"))
                try expectValidationError(project, .invalidTargetConfigFile(target: "target1", configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(project, .invalidTargetSchemeTest(target: "target1", testTarget: "invalidTarget"))
                try expectValidationError(project, .invalidTargetSource(target: "target1", source: "invalidSource"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: "preBuildScript1", path: "invalidPreBuildScript"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: nil, path: "invalidPostCompileScript"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: nil, path: "invalidPostBuildScript"))

                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .debug))
                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .release))

                project.targets[0].scheme?.configVariants = ["invalidVariant"]
                try expectValidationError(project, .invalidTargetSchemeConfigVariant(target: "target1", configVariant: "invalidVariant", configType: .debug))
            }

            $0.it("fails with invalid aggregate target") {
                var project = baseProject
                project.aggregateTargets = [AggregateTarget(
                    name: "target1",
                    targets: ["invalidDependency"],
                    settings: invalidSettings,
                    configFiles: ["invalidConfig": "invalidConfigFile"],
                    buildScripts: [BuildScript(script: .path("invalidPrebuildScript"), name: "buildScript1")],
                    scheme: TargetScheme(testTargets: ["invalidTarget"])
                )]

                try expectValidationError(project, .invalidTargetDependency(target: "target1", dependency: "invalidDependency"))
                try expectValidationError(project, .invalidTargetConfigFile(target: "target1", configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(project, .invalidTargetSchemeTest(target: "target1", testTarget: "invalidTarget"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: "buildScript1", path: "invalidPrebuildScript"))

                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .debug))
                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .release))

                project.aggregateTargets[0].scheme?.configVariants = ["invalidVariant"]
                try expectValidationError(project, .invalidTargetSchemeConfigVariant(target: "target1", configVariant: "invalidVariant", configType: .debug))
            }

            $0.it("fails with invalid sdk dependency") {
                var project = baseProject
                project.targets = [
                    Target(
                        name: "target1",
                        type: .application,
                        platform: .iOS,
                        dependencies: [Dependency(type: .sdk(root: nil), reference: "invalidDependency")]
                    ),
                ]

                try expectValidationError(project, .invalidSDKDependency(target: "target1", dependency: "invalidDependency"))
            }

            $0.it("fails with invalid scheme") {
                var project = baseProject
                project.schemes = [Scheme(
                    name: "scheme1",
                    build: .init(targets: [.init(target: "invalidTarget")]),
                    run: .init(config: "debugInvalid"),
                    test: .init(config: "testInvalid", coverageTargets: ["SubProject/Yams"], targets: [.init(targetReference: "invalidTarget")]),
                    archive: .init(config: "releaseInvalid")
                )]

                try expectValidationError(project, .invalidSchemeTarget(scheme: "scheme1", target: "invalidTarget", action: "build"))
                try expectValidationError(project, .invalidSchemeConfig(scheme: "scheme1", config: "debugInvalid"))
                try expectValidationError(project, .invalidSchemeConfig(scheme: "scheme1", config: "releaseInvalid"))
                try expectValidationError(project, .invalidSchemeTarget(scheme: "scheme1", target: "invalidTarget", action: "test"))
                try expectValidationError(project, .invalidProjectReference(scheme: "scheme1", reference: "SubProject"))
            }

            $0.it("fails with invalid project reference in scheme") {
                var project = baseProject
                project.schemes = [Scheme(
                    name: "scheme1",
                    build: .init(targets: [.init(target: "invalidProjectRef/target1")])
                )]
                try expectValidationError(project, .invalidProjectReference(scheme: "scheme1", reference: "invalidProjectRef"))
            }

            $0.it("fails with invalid project reference path") {
                var project = baseProject
                let reference = ProjectReference(name: "InvalidProj", path: "invalid_path")
                project.projectReferences = [reference]
                try expectValidationError(project, .invalidProjectReferencePath(reference))
            }

            $0.it("fails with invalid project reference in dependency") {
                var project = baseProject
                project.targets = [
                    Target(
                        name: "target1",
                        type: .application,
                        platform: .iOS,
                        dependencies: [Dependency(type: .target, reference: "invalidProjectRef/target2")]
                    ),
                ]
                try expectValidationError(project, .invalidTargetDependency(target: "target1", dependency: "invalidProjectRef/target2"))
            }

            $0.it("allows project reference in target dependency") {
                var project = baseProject
                let externalProjectPath = fixturePath + "TestProject/AnotherProject/AnotherProject.xcodeproj"
                project.projectReferences = [
                    ProjectReference(name: "validProjectRef", path: externalProjectPath.string),
                ]
                project.targets = [
                    Target(
                        name: "target1",
                        type: .application,
                        platform: .iOS,
                        dependencies: [Dependency(type: .target, reference: "validProjectRef/ExternalTarget")]
                    ),
                ]
                try project.validate()
            }

            $0.it("allows missing optional file") {
                var project = baseProject
                project.targets = [Target(
                    name: "target1",
                    type: .application,
                    platform: .iOS,
                    sources: [.init(path: "generated.swift", optional: true)]
                )]
                try project.validate()
            }

            $0.it("validates missing default configurations") {
                var project = baseProject
                project.options = SpecOptions(defaultConfig: "foo")
                try expectValidationError(project, .missingDefaultConfig(configName: "foo"))
            }

            $0.it("validates config settings format") {
                var project = baseProject
                project.configs = Config.defaultConfigs
                project.settings.buildSettings = ["Debug": ["SETTING": "VALUE"], "Release": ["SETTING": "VALUE"]]

                try expectValidationError(project, .invalidPerConfigSettings)
            }

            $0.it("allows custom scheme for aggregated target") {
                var project = baseProject
                let buildScript = BuildScript(script: .path(#file), name: "buildScript1")
                let aggregatedTarget = AggregateTarget(
                    name: "target1",
                    targets: [],
                    settings: Settings(buildSettings: [:]),
                    configFiles: [:],
                    buildScripts: [buildScript],
                    scheme: nil,
                    attributes: [:]
                )
                project.aggregateTargets = [aggregatedTarget]
                let buildTarget = Scheme.BuildTarget(target: "target1")
                let scheme = Scheme(name: "target1-Scheme", build: Scheme.Build(targets: [buildTarget]))
                project.schemes = [scheme]
                try project.validate()
            }
        }
    }

    func testJSONEncodable() {
        describe {
            $0.it("encodes to json") {
                let proj = Project(basePath: Path.current,
                                   name: "ToJson",
                                   configs: [Config(name: "DevelopmentConfig", type: .debug), Config(name: "ProductionConfig", type: .release)],
                                   targets: [Target(name: "App",
                                                    type: .application,
                                                    platform: .iOS,
                                                    productName: "App",
                                                    deploymentTarget: Version(major: 0, minor: 1, patch: 2),
                                                    settings: Settings(buildSettings: ["foo": "bar"],
                                                                       configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                                                                                        configSettings: [:],
                                                                                                        groups: ["config-setting-group"])],
                                                                       groups: ["setting-group"]),
                                                    configFiles: ["foo": "bar"],
                                                    sources: [TargetSource(path: "Source",
                                                                           name: "Source",
                                                                           compilerFlags: ["-Werror"],
                                                                           excludes: ["foo", "bar"],
                                                                           type: .folder,
                                                                           optional: true,
                                                                           buildPhase: .resources,
                                                                           headerVisibility: .private,
                                                                           createIntermediateGroups: true)],
                                                    dependencies: [Dependency(type: .carthage(findFrameworks: true, linkType: .dynamic),
                                                                              reference: "reference",
                                                                              embed: true,
                                                                              codeSign: true,
                                                                              link: true,
                                                                              implicit: true,
                                                                              weakLink: true)],
                                                    info: Plist(path: "info.plist", attributes: ["foo": "bar"]),
                                                    entitlements: Plist(path: "entitlements.plist", attributes: ["foo": "bar"]),
                                                    transitivelyLinkDependencies: true,
                                                    directlyEmbedCarthageDependencies: true,
                                                    requiresObjCLinking: true,
                                                    preBuildScripts: [BuildScript(script: .script("pwd"),
                                                                                  name: "Foo script",
                                                                                  inputFiles: ["foo"],
                                                                                  outputFiles: ["bar"],
                                                                                  inputFileLists: ["foo.xcfilelist"],
                                                                                  outputFileLists: ["bar.xcfilelist"],
                                                                                  shell: "/bin/bash",
                                                                                  runOnlyWhenInstalling: true,
                                                                                  showEnvVars: true,
                                                                                  basedOnDependencyAnalysis: false)],
                                                    postCompileScripts: [BuildScript(script: .path("cmd.sh"),
                                                                                     name: "Bar script",
                                                                                     inputFiles: ["foo"],
                                                                                     outputFiles: ["bar"],
                                                                                     inputFileLists: ["foo.xcfilelist"],
                                                                                     outputFileLists: ["bar.xcfilelist"],
                                                                                     shell: "/bin/bash",
                                                                                     runOnlyWhenInstalling: true,
                                                                                     showEnvVars: true,
                                                                                     basedOnDependencyAnalysis: false)],
                                                    postBuildScripts: [BuildScript(script: .path("cmd.sh"),
                                                                                   name: "an another script",
                                                                                   inputFiles: ["foo"],
                                                                                   outputFiles: ["bar"],
                                                                                   inputFileLists: ["foo.xcfilelist"],
                                                                                   outputFileLists: ["bar.xcfilelist"],
                                                                                   shell: "/bin/bash",
                                                                                   runOnlyWhenInstalling: true,
                                                                                   showEnvVars: true,
                                                                                   basedOnDependencyAnalysis: false)],
                                                    buildRules: [BuildRule(fileType: .pattern("*.xcassets"),
                                                                           action: .script("pre_process_swift.py"),
                                                                           name: "My Build Rule",
                                                                           outputFiles: ["$(SRCROOT)/Generated.swift"],
                                                                           outputFilesCompilerFlags: ["foo"]),
                                                                 BuildRule(fileType: .type("sourcecode.swift"),
                                                                           action: .compilerSpec("com.apple.xcode.tools.swift.compiler"),
                                                                           name: nil,
                                                                           outputFiles: ["bar"],
                                                                           outputFilesCompilerFlags: ["foo"])],
                                                    scheme: TargetScheme(testTargets: [Scheme.Test.TestTarget(targetReference: "test target",
                                                                                                              randomExecutionOrder: false,
                                                                                                              parallelizable: false)],
                                                                         configVariants: ["foo"],
                                                                         gatherCoverageData: true,
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
                                                    legacy: LegacyTarget(toolPath: "foo",
                                                                         passSettings: true,
                                                                         arguments: "bar",
                                                                         workingDirectory: "foo"),
                                                    attributes: ["foo": "bar"])],
                                   aggregateTargets: [AggregateTarget(name: "aggregate target",
                                                                      targets: ["App"],
                                                                      settings: Settings(buildSettings: ["buildSettings": "bar"],
                                                                                         configSettings: ["configSettings": Settings(buildSettings: [:],
                                                                                                                                     configSettings: [:],
                                                                                                                                     groups: [])],
                                                                                         groups: ["foo"]),
                                                                      configFiles: ["configFiles": "bar"],
                                                                      buildScripts: [BuildScript(script: .path("script"),
                                                                                                 name: "foo",
                                                                                                 inputFiles: ["foo"],
                                                                                                 outputFiles: ["bar"],
                                                                                                 inputFileLists: ["foo.xcfilelist"],
                                                                                                 outputFileLists: ["bar.xcfilelist"],
                                                                                                 shell: "/bin/bash",
                                                                                                 runOnlyWhenInstalling: true,
                                                                                                 showEnvVars: false,
                                                                                                 basedOnDependencyAnalysis: false)],
                                                                      scheme: TargetScheme(testTargets: [Scheme.Test.TestTarget(targetReference: "test target",
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
                                                                      attributes: ["foo": "bar"])],
                                   settings: Settings(buildSettings: ["foo": "bar"],
                                                      configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                                                                       configSettings: [:],
                                                                                       groups: ["config-setting-group"])],
                                                      groups: ["setting-group"]),
                                   settingGroups: ["foo": Settings(buildSettings: ["foo": "bar"],
                                                                   configSettings: ["foo": Settings(buildSettings: ["nested": "config"],
                                                                                                    configSettings: [:],
                                                                                                    groups: ["config-setting-group"])],
                                                                   groups: ["setting-group"])],
                                   schemes: [Scheme(name: "scheme",
                                                    build: Scheme.Build(targets: [Scheme.BuildTarget(target: "foo",
                                                                                                     buildTypes: [.archiving, .analyzing])],
                                                                        parallelizeBuild: false,
                                                                        buildImplicitDependencies: false,
                                                                        preActions: [Scheme.ExecutionAction(name: "preAction",
                                                                                                            script: "bar",
                                                                                                            settingsTarget: "foo")],
                                                                        postActions: [Scheme.ExecutionAction(name: "postAction",
                                                                                                             script: "bar",
                                                                                                             settingsTarget: "foo")]),
                                                    run: Scheme.Run(config: "run config",
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
                                                                    launchAutomaticallySubstyle: "2"),
                                                    test: Scheme.Test(config: "Config",
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
                                                    profile: Scheme.Profile(config: "profile config",
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
                                                    analyze: Scheme.Analyze(config: "analyze config"),
                                                    archive: Scheme.Archive(config: "archive config",
                                                                            customArchiveName: "customArchiveName",
                                                                            revealArchiveInOrganizer: true,
                                                                            preActions: [Scheme.ExecutionAction(name: "preAction",
                                                                                                                script: "bar",
                                                                                                                settingsTarget: "foo")],
                                                                            postActions: [Scheme.ExecutionAction(name: "postAction",
                                                                                                                 script: "bar",
                                                                                                                 settingsTarget: "foo")]))],
                                   packages: [
                                       "Yams": .remote(
                                           url: "https://github.com/jpsim/Yams",
                                           versionRequirement: .upToNextMajorVersion("2.0.0")
                                       ),
                                   ],
                                   options: SpecOptions(minimumXcodeGenVersion: Version(major: 3, minor: 4, patch: 5),
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
                                                        deploymentTarget: DeploymentTarget(iOS: Version(major: 1, minor: 2, patch: 3),
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
                                   attributes: ["attributes": "bar"])

                let json = proj.toJSONDictionary()
                let restoredProj = try Project(basePath: Path.current, jsonDictionary: json)

                // Examine some properties to make debugging easier
                try expect(proj.aggregateTargets) == restoredProj.aggregateTargets
                try expect(proj.configFiles) == restoredProj.configFiles
                try expect(proj.settings) == restoredProj.settings
                try expect(proj.basePath) == restoredProj.basePath
                try expect(proj.fileGroups) == restoredProj.fileGroups
                try expect(proj.schemes) == restoredProj.schemes
                try expect(proj.options) == restoredProj.options
                try expect(proj.settingGroups) == restoredProj.settingGroups
                try expect(proj.targets) == restoredProj.targets
                try expect(proj.packages) == restoredProj.packages

                try expect(proj) == restoredProj
            }
        }
    }
}

private func expectValidationError(_ project: Project, _ expectedError: SpecValidationError.ValidationError, file: String = #file, line: Int = #line) throws {
    do {
        try project.validate()
    } catch let error as SpecValidationError {
        if !error.errors
            .contains(where: { $0.description == expectedError.description }) {
            throw failure("Supposed to fail with:\n\(expectedError)\nbut got:\n\(error.errors.map { $0.description }.joined(separator: "\n"))", file: file, line: line)
        }
        return
    } catch {
        throw failure("Supposed to fail with \"\(expectedError)\"", file: file, line: line)
    }
    throw failure("Supposed to fail with \"\(expectedError)\"", file: file, line: line)
}
