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

            $0.it("validates scheme variants") {

                func expectVariant(_ variant: String, type: ConfigType = .debug, for config: Config, matches: Bool, file: String = #file, line: Int = #line) throws {
                    let configs = [Config(name: "xxxxxxxxxxx", type: .debug), config]
                    let foundConfig = configs.first(including: variant, for: type)
                    let found = foundConfig != nil && foundConfig != configs[0]
                    try expect(found, file: file, line: line) == matches
                }

                try expectVariant("Dev", for: Config(name: "DevDebug", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "Dev debug", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "DEV DEBUG", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "Debug Dev", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "dev Debug", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "Dev debug", type: .release), matches: false)
                try expectVariant("Dev", for: Config(name: "Dev-debug", type: .debug), matches: true)
                try expectVariant("Dev", for: Config(name: "Dev_debug", type: .debug), matches: true)
                try expectVariant("Prod", for: Config(name: "PreProd debug", type: .debug), matches: false)
                try expectVariant("Develop", for: Config(name: "Dev debug", type: .debug), matches: false)
                try expectVariant("Development", for: Config(name: "Debug (Development)", type: .debug), matches: true)
                try expectVariant("Staging", for: Config(name: "Debug (Staging)", type: .debug), matches: true)
                try expectVariant("Production", for: Config(name: "Debug (Production)", type: .debug), matches: true)
            }
        }
    }

    func testJSONEncodable() {
        describe {
            $0.it("encodes to json") {
                
                let proj = testProject
                let json = proj.toJSONDictionary()

                try expect(JSONSerialization.isValidJSONObject(json)).beTrue()

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
