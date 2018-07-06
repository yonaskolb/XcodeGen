import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcodeproj
import XCTest

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

    func testDeploymentTarget() {
        describe {

            $0.it("has correct build setting") {
                try expect(Platform.iOS.deploymentTargetSetting) == "IPHONEOS_DEPLOYMENT_TARGET"
                try expect(Platform.tvOS.deploymentTargetSetting) == "TVOS_DEPLOYMENT_TARGET"
                try expect(Platform.watchOS.deploymentTargetSetting) == "WATCHOS_DEPLOYMENT_TARGET"
                try expect(Platform.macOS.deploymentTargetSetting) == "MACOSX_DEPLOYMENT_TARGET"
            }

            $0.it("parses version correctly") {
                try expect(Version("2").deploymentTarget) == "2.0"
                try expect(Version("2.0").deploymentTarget) == "2.0"
                try expect(Version("2.1").deploymentTarget) == "2.1"
                try expect(Version("2.10").deploymentTarget) == "2.10"
                try expect(Version("2.1.0").deploymentTarget) == "2.1"
                try expect(Version("2.12.0").deploymentTarget) == "2.12"
                try expect(Version("2.1.2").deploymentTarget) == "2.1.2"
                try expect(Version("2.10.2").deploymentTarget) == "2.10.2"
                try expect(Version("2.0.2").deploymentTarget) == "2.0.2"
                try expect(Version(2).deploymentTarget) == "2.0"
                try expect(Version(2.0).deploymentTarget) == "2.0"
                try expect(Version(2.1).deploymentTarget) == "2.1"
            }
        }
    }

    func testValidation() {
        describe {

            let baseProject = Project(basePath: "", name: "", configs: [Config(name: "invalid")])
            let invalidSettings = Settings(
                configSettings: ["invalidConfig": [:]],
                groups: ["invalidSettingGroup"]
            )
            $0.it("fails with invalid project") {
                var project = baseProject
                project.settings = invalidSettings
                project.configFiles = ["invalidConfig": "invalidConfigFile"]
                project.fileGroups = ["invalidFileGroup"]
                project.settingGroups = ["settingGroup1": Settings(
                    configSettings: ["invalidSettingGroupConfig": [:]],
                    groups: ["invalidSettingGroupSettingGroup"]
                )]

                try expectValidationError(project, .invalidConfigFileConfig("invalidConfig"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(project, .invalidConfigFile(configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(project, .invalidFileGroup("invalidFileGroup"))
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

            $0.it("fails with invalid target") {
                var project = baseProject
                project.targets = [Target(
                    name: "target1",
                    type: .application,
                    platform: .iOS,
                    settings: invalidSettings,
                    configFiles: ["invalidConfig": "invalidConfigFile"],
                    sources: ["invalidSource"],
                    dependencies: [Dependency(type: .target, reference: "invalidDependency")],
                    prebuildScripts: [BuildScript(script: .path("invalidPrebuildScript"), name: "prebuildScript1")],
                    postbuildScripts: [BuildScript(script: .path("invalidPostbuildScript"))],
                    scheme: TargetScheme(testTargets: ["invalidTarget"])
                )]

                try expectValidationError(project, .invalidTargetDependency(target: "target1", dependency: "invalidDependency"))
                try expectValidationError(project, .invalidTargetConfigFile(target: "target1", configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(project, .invalidTargetSchemeTest(target: "target1", testTarget: "invalidTarget"))
                try expectValidationError(project, .invalidTargetSource(target: "target1", source: "invalidSource"))
                try expectValidationError(project, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(project, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: "prebuildScript1", path: "invalidPrebuildScript"))
                try expectValidationError(project, .invalidBuildScriptPath(target: "target1", name: nil, path: "invalidPostbuildScript"))

                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .debug))
                try expectValidationError(project, .missingConfigForTargetScheme(target: "target1", configType: .release))

                project.targets[0].scheme?.configVariants = ["invalidVariant"]
                try expectValidationError(project, .invalidTargetSchemeConfigVariant(target: "target1", configVariant: "invalidVariant", configType: .debug))
            }

            $0.it("fails with invalid scheme") {
                var project = baseProject
                project.schemes = [Scheme(
                    name: "scheme1",
                    build: .init(targets: [.init(target: "invalidTarget")]),
                    run: .init(config: "debugInvalid"),
                    archive: .init(config: "releaseInvalid")
                )]

                try expectValidationError(project, .invalidSchemeTarget(scheme: "scheme1", target: "invalidTarget"))
                try expectValidationError(project, .invalidSchemeConfig(scheme: "scheme1", config: "debugInvalid"))
                try expectValidationError(project, .invalidSchemeConfig(scheme: "scheme1", config: "releaseInvalid"))
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
        }
    }
}

fileprivate func expectValidationError(_ project: Project, _ expectedError: SpecValidationError.ValidationError, file: String = #file, line: Int = #line) throws {
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
