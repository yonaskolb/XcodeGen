import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcproj

func projectSpecTests() {

    describe("ProjectSpec") {

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

        func expectValidationError(_ spec: ProjectSpec.Project, _ expectedError: SpecValidationError.ValidationError) throws {
            do {
                try spec.validate()
            } catch let error as SpecValidationError {
                if !error.errors
                    .contains(where: { $0.description == expectedError.description }) {
                    throw failure("Supposed to fail with:\n\(expectedError)\nbut got:\n\(error.errors.map { $0.description }.joined(separator: "\n"))")
                }
                return
            } catch {
                throw failure("Supposed to fail with \"\(expectedError)\"")
            }
            throw failure("Supposed to fail with \"\(expectedError)\"")
        }

        $0.describe("Types") {
            $0.it("is a framework when it has the right extension") {
                try expect(framework.type.isFramework).to.beTrue()
            }

            $0.it("is a library when it has the right type") {
                try expect(staticLibrary.type.isLibrary).to.beTrue()
                try expect(dynamicLibrary.type.isLibrary).to.beTrue()
            }
        }

        $0.describe("Deployment Target") {

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

        $0.describe("Validation") {

            let baseSpec = ProjectSpec.Project(basePath: "", name: "", configs: [Config(name: "invalid")])
            let invalidSettings = Settings(
                configSettings: ["invalidConfig": [:]],
                groups: ["invalidSettingGroup"]
            )
            $0.it("fails with invalid project") {
                var spec = baseSpec
                spec.settings = invalidSettings
                spec.configFiles = ["invalidConfig": "invalidConfigFile"]
                spec.fileGroups = ["invalidFileGroup"]
                spec.settingGroups = ["settingGroup1": Settings(
                    configSettings: ["invalidSettingGroupConfig": [:]],
                    groups: ["invalidSettingGroupSettingGroup"]
                )]

                try expectValidationError(spec, .invalidConfigFileConfig("invalidConfig"))
                try expectValidationError(spec, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(spec, .invalidConfigFile(configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(spec, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(spec, .invalidFileGroup("invalidFileGroup"))
                try expectValidationError(spec, .invalidSettingsGroup("invalidSettingGroupSettingGroup"))
                try expectValidationError(spec, .invalidBuildSettingConfig("invalidSettingGroupConfig"))
            }

            $0.it("allows non-existent configurations") {
                var spec = baseSpec
                spec.options = ProjectSpec.Project.Options(disabledValidations: [.missingConfigs])
                let configPath = fixturePath + "test.xcconfig"
                spec.configFiles = ["missingConfiguration": configPath.string]
                try spec.validate()
            }

            $0.it("fails with invalid target") {
                var spec = baseSpec
                spec.targets = [Target(
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

                try expectValidationError(spec, .invalidTargetDependency(target: "target1", dependency: "invalidDependency"))
                try expectValidationError(spec, .invalidTargetConfigFile(target: "target1", configFile: "invalidConfigFile", config: "invalidConfig"))
                try expectValidationError(spec, .invalidTargetSchemeTest(target: "target1", testTarget: "invalidTarget"))
                try expectValidationError(spec, .invalidTargetSource(target: "target1", source: "invalidSource"))
                try expectValidationError(spec, .invalidBuildSettingConfig("invalidConfig"))
                try expectValidationError(spec, .invalidSettingsGroup("invalidSettingGroup"))
                try expectValidationError(spec, .invalidBuildScriptPath(target: "target1", name: "prebuildScript1", path: "invalidPrebuildScript"))
                try expectValidationError(spec, .invalidBuildScriptPath(target: "target1", name: nil, path: "invalidPostbuildScript"))

                try expectValidationError(spec, .missingConfigForTargetScheme(target: "target1", configType: .debug))
                try expectValidationError(spec, .missingConfigForTargetScheme(target: "target1", configType: .release))

                spec.targets[0].scheme?.configVariants = ["invalidVariant"]
                try expectValidationError(spec, .invalidTargetSchemeConfigVariant(target: "target1", configVariant: "invalidVariant", configType: .debug))
            }

            $0.it("fails with invalid scheme") {
                var spec = baseSpec
                spec.schemes = [Scheme(
                    name: "scheme1",
                    build: .init(targets: [.init(target: "invalidTarget")]),
                    run: .init(config: "debugInvalid"),
                    archive: .init(config: "releaseInvalid")
                )]

                try expectValidationError(spec, .invalidSchemeTarget(scheme: "scheme1", target: "invalidTarget"))
                try expectValidationError(spec, .invalidSchemeConfig(scheme: "scheme1", config: "debugInvalid"))
                try expectValidationError(spec, .invalidSchemeConfig(scheme: "scheme1", config: "releaseInvalid"))
            }

            $0.it("allows missing optional file") {
                var spec = baseSpec
                spec.targets = [Target(
                    name: "target1",
                    type: .application,
                    platform: .iOS,
                    sources: [.init(path: "generated.swift", optional: true)]
                )]
                try spec.validate()
            }

            $0.it("validates missing default configurations") {
                var spec = baseSpec
                spec.options = ProjectSpec.Options(defaultConfig: "foo")
                try expectValidationError(spec, .missingDefaultConfig(configName: "foo"))
            }
        }
    }
}
