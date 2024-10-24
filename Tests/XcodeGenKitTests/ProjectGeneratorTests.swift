import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XcodeProj
import XCTest
import Yams
import TestSupport

private let app = Target(
    name: "MyApp",
    type: .application,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyFramework")]
)

private let framework = Target(
    name: "MyFramework",
    type: .framework,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
)

private let optionalFramework = Target(
    name: "MyOptionalFramework",
    type: .framework,
    platform: .iOS
)

private let uiTest = Target(
    name: "MyAppUITests",
    type: .uiTestBundle,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_3": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyApp")]
)

private let targets = [app, framework, optionalFramework, uiTest]

class ProjectGeneratorTests: XCTestCase {

    func testOptions() throws {

        describe {

            $0.it("generates bundle id") {
                let options = SpecOptions(bundleIdPrefix: "com.test")
                let project = Project(name: "test", targets: [framework], options: options)
                let pbxProj = try project.generatePbxProj()

                guard let target = pbxProj.nativeTargets.first,
                    let buildConfigList = target.buildConfigurationList,
                    let buildConfig = buildConfigList.buildConfigurations.first else {
                    throw failure("Build Config not found")
                }
                try expect(buildConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String) == "com.test.MyFramework"
            }

            $0.it("clears setting presets") {
                let options = SpecOptions(settingPresets: .none)
                let project = Project(name: "test", targets: [framework], options: options)
                let pbxProj = try project.generatePbxProj()
                let allSettings = pbxProj.buildConfigurations.reduce([:]) { $0.merged($1.buildSettings) }.keys.sorted()
                try expect(allSettings) == ["SDKROOT", "SETTING_2"]
            }

            $0.it("generates development language") {
                let options = SpecOptions(developmentLanguage: "de")
                let project = Project(name: "test", options: options)
                let pbxProj = try project.generatePbxProj()
                let pbxProject = try unwrap(pbxProj.projects.first)
                try expect(pbxProject.developmentRegion) == "de"
            }

            $0.it("formats xcode version") {
                let versions: [String: String] = [
                    "0900": "0900",
                    "1010": "1010",
                    "9": "0900",
                    "9.0": "0900",
                    "9.1": "0910",
                    "9.1.1": "0911",
                    "10": "1000",
                    "10.1": "1010",
                    "10.1.2": "1012",
                ]

                for (version, expected) in versions {
                    try expect(XCodeVersion.parse(version)) == expected
                }
            }

            $0.it("uses the default configuration name") {
                let options = SpecOptions(defaultConfig: "Bconfig")
                let project = Project(name: "test", configs: [Config(name: "Aconfig"), Config(name: "Bconfig")], targets: [framework], options: options)
                let pbxProject = try project.generatePbxProj()

                guard let projectConfigList = pbxProject.projects.first?.buildConfigurationList,
                    let defaultConfigurationName = projectConfigList.defaultConfigurationName
                else {
                    throw failure("Default configuration name not found")
                }

                try expect(defaultConfigurationName) == "Bconfig"
            }

            $0.it("uses the default configuration name for every target in a project") {
                let options = SpecOptions(defaultConfig: "Bconfig")
                let project = Project(
                    name: "test",
                    configs: [
                        Config(name: "Aconfig"),
                        Config(name: "Bconfig"),
                    ],
                    targets: [
                        Target(name: "1", type: .framework, platform: .iOS),
                        Target(name: "2", type: .framework, platform: .iOS),
                    ],
                    options: options
                )
                let pbxProject = try project.generatePbxProj()

                try pbxProject.projects.first?.targets.forEach { target in

                    guard
                        let buildConfigurationList = target.buildConfigurationList,
                        let defaultConfigurationName = buildConfigurationList.defaultConfigurationName else {
                        throw failure("Default configuration name not found")
                    }

                    try expect(defaultConfigurationName) == "Bconfig"
                }
            }
        }
    }

    func testConfigGenerator() {
        describe {

            $0.it("generates config defaults") {
                let project = Project(name: "test")
                let pbxProj = try project.generatePbxProj()
                let configs = pbxProj.buildConfigurations
                try expect(configs.count) == 2
                try expect(configs).contains(name: "Debug")
                try expect(configs).contains(name: "Release")
            }

            $0.it("generates configs") {
                let project = Project(
                    name: "test",
                    configs: [Config(name: "config1"), Config(name: "config2")]
                )
                let pbxProj = try project.generatePbxProj()
                let configs = pbxProj.buildConfigurations
                try expect(configs.count) == 2
                try expect(configs).contains(name: "config1")
                try expect(configs).contains(name: "config2")
            }

            $0.it("clears config settings when missing type") {
                let project = Project(
                    name: "test",
                    configs: [Config(name: "config")]
                )
                let pbxProj = try project.generatePbxProj()
                let config = try unwrap(pbxProj.buildConfigurations.first)

                try expect(config.buildSettings.isEmpty).to.beTrue()
            }

            $0.it("merges settings") {
                let project = try Project(path: fixturePath + "settings_test.yml")
                let config = try unwrap(project.getConfig("config1"))
                let debugProjectSettings = project.getProjectBuildSettings(config: config)

                let target = try unwrap(project.getTarget("Target"))
                let targetDebugSettings = project.getTargetBuildSettings(target: target, config: config)

                var buildSettings = BuildSettings()
                buildSettings += ["SDKROOT": "iphoneos"]
                buildSettings += SettingsPresetFile.base.getBuildSettings()
                buildSettings += SettingsPresetFile.config(.debug).getBuildSettings()

                buildSettings += [
                    "SETTING": "value",
                    "SETTING 5": "value 5",
                    "SETTING 6": "value 6",
                ]
                try expect(debugProjectSettings.equals(buildSettings)).beTrue()

                var expectedTargetDebugSettings = BuildSettings()
                expectedTargetDebugSettings += SettingsPresetFile.platform(.iOS).getBuildSettings()
                expectedTargetDebugSettings += SettingsPresetFile.product(.application).getBuildSettings()
                expectedTargetDebugSettings += SettingsPresetFile.productPlatform(.application, .iOS).getBuildSettings()
                expectedTargetDebugSettings += ["SETTING 2": "value 2", "SETTING 3": "value 3", "SETTING": "value"]

                try expect(targetDebugSettings.equals(expectedTargetDebugSettings)).beTrue()
            }

            $0.it("applies partial config settings") {
                let project = Project(
                    name: "test",
                    configs: [
                        Config(name: "Release", type: .release),
                        Config(name: "Staging Debug", type: .debug),
                        Config(name: "Staging Release", type: .release),
                    ],
                    settings: Settings(configSettings: [
                        "staging": ["SETTING1": "VALUE1"],
                        "debug": ["SETTING2": "VALUE2"],
                        "Release": ["SETTING3": "VALUE3"],
                    ])
                )

                var buildSettings = project.getProjectBuildSettings(config: project.configs[1])
                try expect(buildSettings["SETTING1"] as? String) == "VALUE1"
                try expect(buildSettings["SETTING2"] as? String) == "VALUE2"

                // don't apply partial when exact match
                buildSettings = project.getProjectBuildSettings(config: project.configs[2])
                try expect(buildSettings["SETTING3"]).beNil()
            }

            $0.it("sets project SDKROOT if there is only a single platform") {
                var project = Project(
                    name: "test",
                    targets: [
                        Target(name: "1", type: .application, platform: .iOS),
                        Target(name: "2", type: .framework, platform: .iOS),
                    ]
                )
                var buildSettings = project.getProjectBuildSettings(config: project.configs.first!)
                try expect(buildSettings["SDKROOT"] as? String) == "iphoneos"

                project.targets.append(Target(name: "3", type: .application, platform: .tvOS))
                buildSettings = project.getProjectBuildSettings(config: project.configs.first!)
                try expect(buildSettings["SDKROOT"]).beNil()
            }
        }
    }

    func testAggregateTargets() {
        describe {

            let otherTarget = Target(name: "Other", type: .framework, platform: .iOS, dependencies: [Dependency(type: .target, reference: "AggregateTarget")])
            let otherTarget2 = Target(name: "Other2", type: .framework, platform: .iOS, dependencies: [Dependency(type: .target, reference: "Other")], transitivelyLinkDependencies: true)
            let aggregateTarget = AggregateTarget(name: "AggregateTarget", targets: ["MyApp", "MyFramework"])
            let aggregateTarget2 = AggregateTarget(name: "AggregateTarget2", targets: ["AggregateTarget"])
            let project = Project(name: "test", targets: [app, framework, otherTarget, otherTarget2], aggregateTargets: [aggregateTarget, aggregateTarget2])

            $0.it("generates aggregate targets") {
                let pbxProject = try project.generatePbxProj()
                let nativeTargets = pbxProject.nativeTargets.sorted { $0.name < $1.name }
                let aggregateTargets = pbxProject.aggregateTargets.sorted { $0.name < $1.name }

                try expect(nativeTargets.count) == 4
                try expect(aggregateTargets.count) == 2

                let aggregateTarget1 = aggregateTargets.first { $0.name == "AggregateTarget" }
                try expect(aggregateTarget1?.dependencies.count) == 2

                let aggregateTarget2 = aggregateTargets.first { $0.name == "AggregateTarget2" }
                try expect(aggregateTarget2?.dependencies.count) == 1

                let target1 = nativeTargets.first { $0.name == "Other" }
                try expect(target1?.dependencies.count) == 1

                let target2 = nativeTargets.first { $0.name == "Other2" }
                try expect(target2?.dependencies.count) == 2

                try expect(pbxProject.targetDependencies.count) == 7
            }
        }
    }

    func testTargets() throws {
        try skipIfNecessary()
        describe {

            let project = Project(name: "test", targets: targets)

            $0.it("generates targets") {
                let pbxProject = try project.generatePbxProj()
                let nativeTargets = pbxProject.nativeTargets
                try expect(nativeTargets.count) == 4
                try expect(nativeTargets.contains { $0.name == app.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == framework.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == uiTest.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == optionalFramework.name }).beTrue()
            }

            $0.it("generates legacy target") {
                let target = Target(name: "target", type: .application, platform: .iOS, dependencies: [.init(type: .target, reference: "legacy")])
                let legacyTarget = Target(name: "legacy", type: .none, platform: .iOS, legacy: .init(toolPath: "path"))
                let project = Project(name: "test", targets: [target, legacyTarget])

                let pbxProject = try project.generatePbxProj()
                try expect(pbxProject.legacyTargets.count) == 1
            }

            $0.it("generates target attributes") {
                var appTargetWithAttributes = app
                appTargetWithAttributes.settings.buildSettings["DEVELOPMENT_TEAM"] = "123"
                appTargetWithAttributes.attributes = ["ProvisioningStyle": "Automatic"]

                var testTargetWithAttributes = uiTest
                testTargetWithAttributes.settings.buildSettings["CODE_SIGN_STYLE"] = "Manual"
                let project = Project(name: "test", targets: [appTargetWithAttributes, framework, optionalFramework, testTargetWithAttributes])
                let pbxProject = try project.generatePbxProj()

                let targetAttributes = try unwrap(pbxProject.projects.first?.targetAttributes)
                let appTarget = try unwrap(pbxProject.targets(named: app.name).first)
                let uiTestTarget = try unwrap(pbxProject.targets(named: uiTest.name).first)

                try expect((targetAttributes[uiTestTarget]?["TestTargetID"] as? PBXNativeTarget)?.name) == app.name
                try expect(targetAttributes[uiTestTarget]?["ProvisioningStyle"] as? String) == "Manual"
                try expect(targetAttributes[appTarget]?["ProvisioningStyle"] as? String) == "Automatic"
                try expect(targetAttributes[appTarget]?["DevelopmentTeam"] as? String) == "123"
            }

            $0.it("generates platform version") {
                let target = Target(name: "Target", type: .application, platform: .watchOS, deploymentTarget: "2.0")
                let project = Project(name: "", targets: [target], options: .init(deploymentTarget: DeploymentTarget(iOS: "10.0", watchOS: "3.0")))

                let pbxProject = try project.generatePbxProj()
                let projectConfig = try unwrap(pbxProject.projects.first?.buildConfigurationList?.buildConfigurations.first)
                let targetConfig = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)

                try expect(projectConfig.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String) == "10.0"
                try expect(projectConfig.buildSettings["WATCHOS_DEPLOYMENT_TARGET"] as? String) == "3.0"
                try expect(projectConfig.buildSettings["TVOS_DEPLOYMENT_TARGET"]).beNil()

                try expect(targetConfig.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"]).beNil()
                try expect(targetConfig.buildSettings["WATCHOS_DEPLOYMENT_TARGET"] as? String) == "2.0"
                try expect(targetConfig.buildSettings["TVOS_DEPLOYMENT_TARGET"]).beNil()
            }
            
            $0.it("supportedDestinations merges settings - iOS, tvOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.tvOS, .iOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator appletvos appletvsimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2,3"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }
            
            $0.it("supportedDestinations merges settings - iOS, visionOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.visionOS, .iOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator xros xrsimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2,7"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }
            
            $0.it("supportedDestinations merges settings - iOS, tvOS, macOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.iOS, .tvOS, .macOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator appletvos appletvsimulator macosx"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2,3"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }
            
            $0.it("supportedDestinations merges settings - iOS, tvOS, macCatalyst") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.iOS, .tvOS, .macCatalyst])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator appletvos appletvsimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2,3"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == true
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }
            
            $0.it("supportedDestinations merges settings - iOS, macOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.iOS, .macOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator macosx"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }
            
            $0.it("supportedDestinations merges settings - tvOS, macOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.tvOS, .macOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "appletvos appletvsimulator macosx"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "3"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "App Icon & Top Shelf Image"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME"] as? String) == "LaunchImage"
            }
            
            $0.it("supportedDestinations merges settings - visionOS, macOS") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.visionOS, .macOS])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "xros xrsimulator macosx"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "7"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
            }
            
            $0.it("supportedDestinations merges settings - iOS, macCatalyst") {
                let target = Target(name: "Target", type: .application, platform: .auto, supportedDestinations: [.iOS, .macCatalyst])
                let project = Project(name: "", targets: [target])
                
                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                
                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == true
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                
                try expect(targetConfig1.buildSettings["LD_RUNPATH_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "@executable_path/Frameworks"]
                try expect(targetConfig1.buildSettings["SDKROOT"] as? String) == "auto"
                try expect(targetConfig1.buildSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] as? String) == "AppIcon"
                try expect(targetConfig1.buildSettings["CODE_SIGN_IDENTITY"] as? String) == "iPhone Developer"
            }

            $0.it("supportedDestinations merges settings - iOS, watchOS (framework)") {
                let target = Target(name: "Target", type: .framework, platform: .auto, supportedDestinations: [.iOS, .watchOS])
                let project = Project(name: "", targets: [target])

                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)

                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "iphoneos iphonesimulator watchos watchsimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "1,2,4"
                try expect(targetConfig1.buildSettings["SUPPORTS_MACCATALYST"] as? Bool) == false
                try expect(targetConfig1.buildSettings["SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == true
            }

            $0.it("supportedDestinations merges settings - visionOS, watchOS (framework)") {
                let target = Target(name: "Target", type: .framework, platform: .auto, supportedDestinations: [.visionOS, .watchOS])
                let project = Project(name: "", targets: [target])

                let pbxProject = try project.generatePbxProj()
                let targetConfig1 = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)

                try expect(targetConfig1.buildSettings["SUPPORTED_PLATFORMS"] as? String) == "watchos watchsimulator xros xrsimulator"
                try expect(targetConfig1.buildSettings["TARGETED_DEVICE_FAMILY"] as? String) == "4,7"
                try expect(targetConfig1.buildSettings["SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD"] as? Bool) == false
            }

            $0.it("generates dependencies") {
                let pbxProject = try project.generatePbxProj()

                let nativeTargets = pbxProject.nativeTargets
                let dependencies = pbxProject.targetDependencies.sorted { $0.target?.name ?? "" < $1.target?.name ?? "" }
                try expect(dependencies.count) == 2
                let appTarget = nativeTargets.first { $0.name == app.name }
                let frameworkTarget = nativeTargets.first { $0.name == framework.name }

                try expect(dependencies).contains { $0.target == appTarget }
                try expect(dependencies).contains { $0.target == frameworkTarget }
            }

            $0.it("generates dependency from external project file") {
                let subproject: PBXProj
                prepareXcodeProj: do {
                    let project = try! Project(path: fixturePath + "TestProject/AnotherProject/project.yml")
                    let generator = ProjectGenerator(project: project)
                    let writer = FileWriter(project: project)
                    let xcodeProject = try! generator.generateXcodeProject(userName: "someUser")
                    try! writer.writeXcodeProject(xcodeProject)
                    try! writer.writePlists()
                    subproject = xcodeProject.pbxproj
                }
                let externalProjectPath = fixturePath + "TestProject/AnotherProject/AnotherProject.xcodeproj"
                let projectReference = ProjectReference(name: "AnotherProject", path: externalProjectPath.string)
                var target = app
                target.dependencies = [
                    Dependency(type: .target, reference: "AnotherProject/ExternalTarget"),
                ]
                let project = Project(
                    name: "test",
                    targets: [target],
                    schemes: [],
                    projectReferences: [projectReference]
                )
                let pbxProject = try project.generatePbxProj()

                let projectReferences = pbxProject.rootObject?.projects ?? []
                try expect(projectReferences.count) == 1
                try expect((projectReferences.first?["ProjectRef"])?.name) == "AnotherProject"

                let dependencies = pbxProject.targetDependencies
                let targetUuid = subproject.targets(named: "ExternalTarget").first?.uuid
                try expect(dependencies.count) == 1
                try expect(dependencies).contains { dependency in
                    guard let id = dependency.targetProxy?.remoteGlobalID else { return false }

                    switch id {
                    case .object(let object):
                        return object.uuid == targetUuid
                    case .string(let value):
                        return value == targetUuid
                    }
                }

            }

            $0.it("generates targets with correct transitive embeds") {
                // App # Embeds it's frameworks, so shouldn't embed in tests
                //   dependencies:
                //     - framework: FrameworkA.framework
                //     - framework: FrameworkB.framework
                //       embed: false
                // iOSFrameworkZ:
                //   dependencies: []
                // iOSFrameworkX:
                //   dependencies: []
                // StaticLibrary:
                //   dependencies:
                //     - target: iOSFrameworkZ
                //     - framework: FrameworkZ.framework
                //     - carthage: CarthageZ
                // ResourceBundle
                //   dependencies: []
                // iOSFrameworkA
                //   dependencies:
                //     - target: StaticLibrary
                //     - target: ResourceBundle
                //     # Won't embed FrameworkC.framework, so should embed in tests
                //     - framework: FrameworkC.framework
                //     - carthage: CarthageA
                //     - carthage: CarthageB
                //       embed: false
                //     - package: RxSwift
                //       product: RxSwift
                //     - package: RxSwift
                //       product: RxCocoa
                //     - package: RxSwift
                //       product: RxRelay
                // iOSFrameworkB
                //   dependencies:
                //     - target: iOSFrameworkA
                //     # Won't embed FrameworkD.framework, so should embed in tests
                //     - framework: FrameworkD.framework
                //     - framework: FrameworkE.framework
                //       embed: true
                //     - framework: FrameworkF.framework
                //       embed: false
                //     - carthage: CarthageC
                //       embed: true
                // AppTest
                //   dependencies:
                //     # Being an app, shouldn't be embedded
                //     - target: App
                //     - target: iOSFrameworkB
                //     - carthage: CarthageD
                //     # should be implicitly added
                //     # - target: iOSFrameworkA
                //     #   embed: true
                //     # - target: StaticLibrary
                //     #   embed: false
                //     # - framework: FrameworkZ.framework
                //     # - target: iOSFrameworkZ
                //     #   embed: true
                //     # - carthage: CarthageZ
                //     #   embed: false
                //     # - carthage: CarthageA
                //     #   embed: true
                //     # - framework: FrameworkC.framework
                //     #   embed: true
                //     # - framework: FrameworkD.framework
                //     #   embed: true
                //
                // AppTestWithoutTransitive
                //   dependencies:
                //     # Being an app, shouldn't be embedded
                //     - target: App
                //     - target: iOSFrameworkB
                //     - carthage: CarthageD
                //
                // packages:
                //   RxSwift:
                //     url: https://github.com/ReactiveX/RxSwift
                //     majorVersion: 5.1.0

                var expectedResourceFiles: [String: Set<String>] = [:]
                var expectedBundlesFiles: [String: Set<String>] = [:]
                var expectedLinkedFiles: [String: Set<String>] = [:]
                var expectedEmbeddedFrameworks: [String: Set<String>] = [:]

                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    // Embeds it's frameworks, so they shouldn't embed in AppTest
                    dependencies: [
                        Dependency(type: .framework, reference: "FrameworkA.framework"),
                        Dependency(type: .framework, reference: "FrameworkB.framework", embed: false),
                    ]
                )
                expectedResourceFiles[app.name] = Set()
                expectedLinkedFiles[app.name] = Set([
                    "FrameworkA.framework",
                    "FrameworkB.framework",
                ])
                expectedEmbeddedFrameworks[app.name] = Set([
                    "FrameworkA.framework",
                ])

                let iosFrameworkZ = Target(
                    name: "iOSFrameworkZ",
                    type: .framework,
                    platform: .iOS,
                    dependencies: []
                )
                expectedResourceFiles[iosFrameworkZ.name] = Set()
                expectedLinkedFiles[iosFrameworkZ.name] = Set()
                expectedEmbeddedFrameworks[iosFrameworkZ.name] = Set()

                let iosFrameworkX = Target(
                    name: "iOSFrameworkX",
                    type: .framework,
                    platform: .iOS,
                    dependencies: []
                )
                expectedResourceFiles[iosFrameworkX.name] = Set()
                expectedLinkedFiles[iosFrameworkX.name] = Set()
                expectedEmbeddedFrameworks[iosFrameworkX.name] = Set()

                let staticLibrary = Target(
                    name: "StaticLibrary",
                    type: .staticLibrary,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: iosFrameworkZ.name, link: true),
                        Dependency(type: .framework, reference: "FrameworkZ.framework", link: true),
                        Dependency(type: .target, reference: iosFrameworkX.name /* , link: false */ ),
                        Dependency(type: .framework, reference: "FrameworkX.framework" /* , link: false */ ),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "CarthageZ"),
                        Dependency(type: .bundle, reference: "BundleA.bundle"),
                    ]
                )
                expectedResourceFiles[staticLibrary.name] = Set()
                expectedBundlesFiles[staticLibrary.name] = Set()
                expectedLinkedFiles[staticLibrary.name] = Set([
                    iosFrameworkZ.filename,
                    "FrameworkZ.framework",
                ])
                expectedEmbeddedFrameworks[staticLibrary.name] = Set()

                let resourceBundle = Target(
                    name: "ResourceBundle",
                    type: .bundle,
                    platform: .iOS,
                    dependencies: []
                )
                expectedResourceFiles[resourceBundle.name] = Set()
                expectedLinkedFiles[resourceBundle.name] = Set()
                expectedEmbeddedFrameworks[resourceBundle.name] = Set()

                let iosFrameworkA = Target(
                    name: "iOSFrameworkA",
                    type: .framework,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: resourceBundle.name),
                        Dependency(type: .framework, reference: "FrameworkC.framework"),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "CarthageA"),
                        Dependency(type: .package(products: ["RxSwift"]), reference: "RxSwift"),
                        Dependency(type: .package(products: ["RxCocoa"]), reference: "RxSwift"),
                        Dependency(type: .package(products: ["RxRelay"]), reference: "RxSwift"),

                        // Validate - Do not link package
                        Dependency(type: .package(products: ["KeychainAccess"]), reference: "KeychainAccess", link: false),

                        // Statically linked, so don't embed into test
                        Dependency(type: .target, reference: staticLibrary.name),

                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "CarthageB", embed: false),
                        Dependency(type: .bundle, reference: "BundleA.bundle"),
                    ]
                )
                expectedResourceFiles[iosFrameworkA.name] = Set()
                expectedBundlesFiles[iosFrameworkA.name] = Set([
                    "BundleA.bundle",
                ])
                expectedLinkedFiles[iosFrameworkA.name] = Set([
                    "FrameworkC.framework",
                    iosFrameworkZ.filename,
                    iosFrameworkX.filename,
                    "FrameworkZ.framework",
                    "FrameworkX.framework",
                    "CarthageZ.framework",
                    "CarthageA.framework",
                    "CarthageB.framework",
                    "RxSwift",
                    "RxCocoa",
                    "RxRelay",
                ])
                expectedEmbeddedFrameworks[iosFrameworkA.name] = Set()

                let iosFrameworkB = Target(
                    name: "iOSFrameworkB",
                    type: .framework,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: iosFrameworkA.name),
                        Dependency(type: .framework, reference: "FrameworkD.framework"),
                        // Embedded into framework, so don't embed into test
                        Dependency(type: .framework, reference: "FrameworkE.framework", embed: true),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "CarthageC", embed: true),
                        // Statically linked, so don't embed into test
                        Dependency(type: .framework, reference: "FrameworkF.framework", embed: false),
                    ]
                )
                expectedResourceFiles[iosFrameworkB.name] = Set()
                expectedLinkedFiles[iosFrameworkB.name] = Set([
                    iosFrameworkA.filename,
                    iosFrameworkZ.filename,
                    iosFrameworkX.filename,
                    "FrameworkZ.framework",
                    "FrameworkX.framework",
                    "CarthageZ.framework",
                    "FrameworkC.framework",
                    "FrameworkD.framework",
                    "FrameworkE.framework",
                    "FrameworkF.framework",
                    "CarthageA.framework",
                    "CarthageB.framework",
                    "CarthageC.framework",
                    "RxSwift",
                    "RxCocoa",
                    "RxRelay",
                ])
                expectedEmbeddedFrameworks[iosFrameworkB.name] = Set([
                    "FrameworkE.framework",
                    "CarthageC.framework",
                ])

                let appTest = Target(
                    name: "AppTest",
                    type: .unitTestBundle,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: app.name),
                        Dependency(type: .target, reference: iosFrameworkB.name),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "CarthageD"),
                    ],
                    directlyEmbedCarthageDependencies: false
                )
                expectedResourceFiles[appTest.name] = Set([
                    resourceBundle.filename,
                ])
                expectedLinkedFiles[appTest.name] = Set([
                    iosFrameworkA.filename,
                    staticLibrary.filename,
                    iosFrameworkZ.filename,
                    iosFrameworkX.filename,
                    "FrameworkZ.framework",
                    "FrameworkX.framework",
                    "CarthageZ.framework",
                    "FrameworkF.framework",
                    "FrameworkC.framework",
                    iosFrameworkB.filename,
                    "FrameworkD.framework",
                    "CarthageA.framework",
                    "CarthageB.framework",
                    "CarthageD.framework",
                    "RxSwift",
                    "RxCocoa",
                    "RxRelay",
                ])
                expectedEmbeddedFrameworks[appTest.name] = Set([
                    iosFrameworkA.filename,
                    iosFrameworkZ.filename,
                    iosFrameworkX.filename,
                    "FrameworkZ.framework",
                    "FrameworkX.framework",
                    "FrameworkC.framework",
                    iosFrameworkB.filename,
                    "FrameworkD.framework",
                ])

                var appTestWithoutTransitive = appTest
                appTestWithoutTransitive.name = "AppTestWithoutTransitive"
                appTestWithoutTransitive.transitivelyLinkDependencies = false
                expectedResourceFiles[appTestWithoutTransitive.name] = Set([])
                expectedLinkedFiles[appTestWithoutTransitive.name] = Set([
                    iosFrameworkB.filename,
                    "CarthageD.framework",
                ])
                expectedEmbeddedFrameworks[appTestWithoutTransitive.name] = Set([
                    iosFrameworkB.filename,
                ])

                let XCTestPath = "Platforms/iPhoneOS.platform/Developer/Library/Frameworks/XCTest.framework"
                let GXToolsPath = "Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks/GXTools.framework"
                let XCTAutomationPath = "Platforms/iPhoneOS.platform/Developer/Library/PrivateFrameworks/XCTAutomationSupport.framework"
                let stickerPack = Target(
                    name: "MyStickerApp",
                    type: .stickerPack,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .sdk(root: nil), reference: "NotificationCenter.framework"),
                        Dependency(type: .sdk(root: "DEVELOPER_DIR"), reference: XCTestPath),
                        Dependency(type: .sdk(root: "DEVELOPER_DIR"), reference: GXToolsPath, embed: true),
                        Dependency(type: .sdk(root: "DEVELOPER_DIR"), reference: XCTAutomationPath, embed: true, codeSign: true),
                    ]
                )
                expectedResourceFiles[stickerPack.name] = nil
                expectedLinkedFiles[stickerPack.name] = Set([
                    "XCTest.framework",
                    "NotificationCenter.framework",
                    "GXTools.framework",
                    "XCTAutomationSupport.framework"
                ])
                expectedEmbeddedFrameworks[stickerPack.name] = Set([
                    "GXTools.framework",
                    "XCTAutomationSupport.framework"
                ])

                let targets = [app, iosFrameworkZ, iosFrameworkX, staticLibrary, resourceBundle, iosFrameworkA, iosFrameworkB, appTest, appTestWithoutTransitive, stickerPack]

                let packages: [String: SwiftPackage] = [
                    "RxSwift": .remote(url: "https://github.com/ReactiveX/RxSwift", versionRequirement: .upToNextMajorVersion("5.1.1")),
                    "KeychainAccess": .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess", versionRequirement: .upToNextMajorVersion("4.2.0"))
                ]

                let project = Project(
                    name: "test",
                    targets: targets,
                    packages: packages,
                    options: SpecOptions(transitivelyLinkDependencies: true)
                )
                let pbxProject = try project.generatePbxProj()

                for target in targets {
                    let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == target.name }))

                    let buildPhases = nativeTarget.buildPhases
                    let resourcesPhases = pbxProject.resourcesBuildPhases.filter { buildPhases.contains($0) }
                    let frameworkPhases = pbxProject.frameworksBuildPhases.filter { buildPhases.contains($0) }
                    let copyFilesPhases = pbxProject.copyFilesBuildPhases.filter { buildPhases.contains($0) }
                    let embedFrameworkPhase = copyFilesPhases.first { $0.dstSubfolderSpec == .frameworks }
                    let copyBundlesPhase = copyFilesPhases.first { $0.dstSubfolderSpec == .resources }

                    // All targets should have a compile sources phase,
                    // except for the resourceBundle and sticker pack one
                    let targetsGeneratingSourcePhases = targets
                        .filter { ![.bundle, .stickerPack].contains($0.type) }
                    let sourcesPhases = pbxProject.sourcesBuildPhases
                    try expect(sourcesPhases.count) == targetsGeneratingSourcePhases.count

                    // ensure only the right resources are copied, no more, no less
                    if let expectedResourceFiles = expectedResourceFiles[target.name] {
                        try expect(resourcesPhases.count) == (expectedResourceFiles.isEmpty ? 0 : 1)
                        if !expectedResourceFiles.isEmpty {
                            let resourceFiles = (resourcesPhases[0].files ?? [])
                                .compactMap { $0.file }
                                .map { $0.nameOrPath }
                            try expect(Set(resourceFiles)) == expectedResourceFiles
                        }
                    } else {
                        try expect(resourcesPhases.count) == 0
                    }

                    // ensure only the right things are linked, no more, no less
                    let expectedLinkedFiles = expectedLinkedFiles[target.name]!
                    try expect(frameworkPhases.count) == (expectedLinkedFiles.isEmpty ? 0 : 1)

                    if !expectedLinkedFiles.isEmpty {
                        let linkFrameworks = (frameworkPhases[0].files ?? [])
                            .compactMap { $0.file?.nameOrPath }

                        let linkPackages = (frameworkPhases[0].files ?? [])
                            .compactMap { $0.product?.productName }

                        try expect(Array(Set(linkFrameworks + linkPackages)).sorted()) == Array(expectedLinkedFiles).sorted()
                    }

                    var expectedCopyFilesPhasesCount = 0
                    // ensure only the right things are embedded, no more, no less
                    if let expectedEmbeddedFrameworks = expectedEmbeddedFrameworks[target.name], !expectedEmbeddedFrameworks.isEmpty {
                        expectedCopyFilesPhasesCount += 1
                        let copyFiles = (embedFrameworkPhase?.files ?? [])
                            .compactMap { $0.file?.nameOrPath }
                        try expect(Set(copyFiles)) == expectedEmbeddedFrameworks
                    }

                    if let expectedBundlesFiles = expectedBundlesFiles[target.name],
                        target.type != .staticLibrary && target.type != .dynamicLibrary {
                        expectedCopyFilesPhasesCount += 1
                        let copyBundles = (copyBundlesPhase?.files ?? [])
                            .compactMap { $0.file?.nameOrPath }
                        try expect(Set(copyBundles)) == expectedBundlesFiles
                    }
                    try expect(copyFilesPhases.count) == expectedCopyFilesPhasesCount
                }
            }
            
            $0.it("ensures static frameworks are not embedded by default") {
                
                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: "DynamicFramework"),
                        Dependency(type: .target, reference: "DynamicFrameworkNotEmbedded", embed: false),
                        Dependency(type: .target, reference: "StaticFramework"),
                        Dependency(type: .target, reference: "StaticFrameworkExplicitlyEmbedded", embed: true),
                        Dependency(type: .target, reference: "StaticFramework2"),
                        Dependency(type: .target, reference: "StaticFramework2ExplicitlyEmbedded", embed: true),
                        Dependency(type: .target, reference: "StaticLibrary"),
                    ]
                )

                let targets = [
                    app,
                    Target(
                        name: "DynamicFramework",
                        type: .framework,
                        platform: .iOS
                    ),
                    Target(
                        name: "DynamicFrameworkNotEmbedded",
                        type: .framework,
                        platform: .iOS
                    ),
                    Target(
                        name: "StaticFramework",
                        type: .framework,
                        platform: .iOS,
                        settings: Settings(buildSettings: ["MACH_O_TYPE": "staticlib"])
                    ),
                    Target(
                        name: "StaticFrameworkExplicitlyEmbedded",
                        type: .framework,
                        platform: .iOS,
                        settings: Settings(buildSettings: ["MACH_O_TYPE": "staticlib"])
                    ),
                    Target(
                        name: "StaticFramework2",
                        type: .staticFramework,
                        platform: .iOS
                    ),
                    Target(
                        name: "StaticFramework2ExplicitlyEmbedded",
                        type: .staticFramework,
                        platform: .iOS
                    ),
                    Target(
                        name: "StaticLibrary",
                        type: .staticLibrary,
                        platform: .iOS
                    ),
                ]
                                
                let expectedLinkedFiles = Set([
                    "DynamicFramework.framework",
                    "DynamicFrameworkNotEmbedded.framework",
                    "StaticFramework.framework",
                    "StaticFrameworkExplicitlyEmbedded.framework",
                    "StaticFramework2.framework",
                    "StaticFramework2ExplicitlyEmbedded.framework",
                    "libStaticLibrary.a",
                ])
                
                let expectedEmbeddedFrameworks = Set([
                    "DynamicFramework.framework",
                    "StaticFrameworkExplicitlyEmbedded.framework",
                    "StaticFramework2ExplicitlyEmbedded.framework"
                ])
                                
                let project = Project(
                    name: "test",
                    targets: targets
                )
                let pbxProject = try project.generatePbxProj()

                let appTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let buildPhases = appTarget.buildPhases
                let frameworkPhases = pbxProject.frameworksBuildPhases.filter { buildPhases.contains($0) }
                let copyFilesPhases = pbxProject.copyFilesBuildPhases.filter { buildPhases.contains($0) }
                let embedFrameworkPhase = copyFilesPhases.first { $0.dstSubfolderSpec == .frameworks }

                // Ensure all targets are linked
                let linkFrameworks = (frameworkPhases[0].files ?? []).compactMap { $0.file?.nameOrPath }
                let linkPackages = (frameworkPhases[0].files ?? []).compactMap { $0.product?.productName }
                try expect(Set(linkFrameworks + linkPackages)) == expectedLinkedFiles

                // Ensure only dynamic frameworks are embedded (unless there's an explicit override)
                let embeddedFrameworks = Set((embedFrameworkPhase?.files ?? []).compactMap { $0.file?.nameOrPath })
                try expect(embeddedFrameworks) == expectedEmbeddedFrameworks
            }

            $0.it("copies files only on install in the Embed Frameworks step") {
                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    // Embeds it's frameworks, so they shouldn't embed in AppTest
                    dependencies: [
                        Dependency(type: .framework, reference: "FrameworkA.framework"),
                        Dependency(type: .framework, reference: "FrameworkB.framework", embed: false),
                    ],
                    onlyCopyFilesOnInstall: true
                )
                
                let project = Project(name: "test",targets: [app])
                let pbxProject = try project.generatePbxProj()
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let buildPhases = nativeTarget.buildPhases

                let embedFrameworksPhase = pbxProject
                    .copyFilesBuildPhases
                    .filter { buildPhases.contains($0) }
                    .first { $0.dstSubfolderSpec == .frameworks }

                let phase = try unwrap(embedFrameworksPhase)
                try expect(phase.buildActionMask) == PBXProjGenerator.copyFilesActionMask
                try expect(phase.runOnlyForDeploymentPostprocessing) == true
            }

            $0.it("copies files only on install in the Embed App Extensions step") {
                let appExtension = Target(
                    name: "AppExtension",
                    type: .appExtension,
                    platform: .tvOS
                )

                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .tvOS,
                    dependencies: [
                        Dependency(type: .target, reference: "AppExtension")
                    ],
                    onlyCopyFilesOnInstall: true
                )

                let project = Project(name: "test", targets: [app, appExtension])
                let pbxProject = try project.generatePbxProj()
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let buildPhases = nativeTarget.buildPhases

                let embedAppExtensionsPhase = pbxProject
                    .copyFilesBuildPhases
                    .filter { buildPhases.contains($0) }
                    .first { $0.dstSubfolderSpec == .plugins }

                let phase = try unwrap(embedAppExtensionsPhase)
                try expect(phase.buildActionMask) == PBXProjGenerator.copyFilesActionMask
                try expect(phase.runOnlyForDeploymentPostprocessing) == true
            }

            $0.it("copies files only on install in the Embed Frameworks and Embed App Extensions steps") {
                let appExtension = Target(
                    name: "AppExtension",
                    type: .appExtension,
                    platform: .tvOS
                )

                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .tvOS,
                    dependencies: [
                        Dependency(type: .target, reference: "AppExtension"),
                        Dependency(type: .framework, reference: "FrameworkA.framework"),
                        Dependency(type: .framework, reference: "FrameworkB.framework", embed: false),
                    ],
                    onlyCopyFilesOnInstall: true
                )

                let project = Project(name: "test", targets: [app, appExtension])
                let pbxProject = try project.generatePbxProj()
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let buildPhases = nativeTarget.buildPhases

                let embedFrameworksPhase = pbxProject
                    .copyFilesBuildPhases
                    .filter { buildPhases.contains($0) }
                    .first { $0.dstSubfolderSpec == .frameworks }

                let embedFrameworksPhaseValue = try unwrap(embedFrameworksPhase)
                try expect(embedFrameworksPhaseValue.buildActionMask) == PBXProjGenerator.copyFilesActionMask
                try expect(embedFrameworksPhaseValue.runOnlyForDeploymentPostprocessing) == true
                
                let embedAppExtensionsPhase = pbxProject
                    .copyFilesBuildPhases
                    .filter { buildPhases.contains($0) }
                    .first { $0.dstSubfolderSpec == .plugins }

                let embedAppExtensionsPhaseValue = try unwrap(embedAppExtensionsPhase)
                try expect(embedAppExtensionsPhaseValue.buildActionMask) == PBXProjGenerator.copyFilesActionMask
                try expect(embedAppExtensionsPhaseValue.runOnlyForDeploymentPostprocessing) == true
            }
            
            $0.it("sets -ObjC for targets that depend on requiresObjCLinking targets") {
                let requiresObjCLinking = Target(
                    name: "requiresObjCLinking",
                    type: .staticLibrary,
                    platform: .iOS,
                    dependencies: [],
                    requiresObjCLinking: true
                )
                let doesntRequireObjCLinking = Target(
                    name: "doesntRequireObjCLinking",
                    type: .staticLibrary,
                    platform: .iOS,
                    dependencies: [],
                    requiresObjCLinking: false
                )
                let implicitlyRequiresObjCLinking = Target(
                    name: "implicitlyRequiresObjCLinking",
                    type: .staticLibrary,
                    platform: .iOS,
                    sources: [TargetSource(path: "StaticLibrary_ObjC/StaticLibrary_ObjC.m")],
                    dependencies: []
                )

                let framework = Target(
                    name: "framework",
                    type: .framework,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: requiresObjCLinking.name, link: false)]
                )

                let app1 = Target(
                    name: "app1",
                    type: .application,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: requiresObjCLinking.name)]
                )
                let app2 = Target(
                    name: "app2",
                    type: .application,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: doesntRequireObjCLinking.name)]
                )
                let app3 = Target(
                    name: "app3",
                    type: .application,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: implicitlyRequiresObjCLinking.name)]
                )

                let targets = [requiresObjCLinking, doesntRequireObjCLinking, implicitlyRequiresObjCLinking, framework, app1, app2, app3]

                let project = Project(
                    basePath: fixturePath + "TestProject",
                    name: "test",
                    targets: targets,
                    options: SpecOptions()
                )

                let pbxProj = try project.generatePbxProj()

                func buildSettings(for target: Target) throws -> BuildSettings {
                    guard let nativeTarget = pbxProj.targets(named: target.name).first,
                        let buildConfigList = nativeTarget.buildConfigurationList,
                        let buildConfig = buildConfigList.buildConfigurations.first else {
                        throw failure("XCBuildConfiguration not found for Target \(target.name.quoted)")
                    }

                    return buildConfig.buildSettings
                }

                let frameworkOtherLinkerSettings = try buildSettings(for: framework)["OTHER_LDFLAGS"] as? [String] ?? []
                let app1OtherLinkerSettings = try buildSettings(for: app1)["OTHER_LDFLAGS"] as? [String] ?? []
                let app2OtherLinkerSettings = try buildSettings(for: app2)["OTHER_LDFLAGS"] as? [String] ?? []
                let app3OtherLinkerSettings = try buildSettings(for: app3)["OTHER_LDFLAGS"] as? [String] ?? []

                try expect(frameworkOtherLinkerSettings.contains("-ObjC")) == false
                try expect(app1OtherLinkerSettings.contains("-ObjC")) == true
                try expect(app2OtherLinkerSettings.contains("-ObjC")) == false
                try expect(app3OtherLinkerSettings.contains("-ObjC")) == true
            }
            
            $0.it("filter sources with inferDestinationFiltersByPath") {
                let sourceFiles = TargetSource(path: "App_supportedDestinations/TestResources", inferDestinationFiltersByPath: true)
                
                let target = Target(
                    name: "test",
                    type: .application,
                    platform: .auto,
                    sources: [sourceFiles],
                    dependencies: []
                )
                
                let project = Project(
                    basePath: fixturePath + "TestProject",
                    name: "test",
                    targets: [target]
                )
                
                let pbxProject = try project.generatePbxProj()
                let buildFiles = pbxProject.buildFiles
                
                try expect(buildFiles.count) == 8
                
                for buildFile in buildFiles {
                    let name = buildFile.file?.nameOrPath
                    
                    if buildFile.platformFilters == [SupportedDestination.iOS.string] &&
                        (name == "File_ios.swift" || name == "File_A.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.tvOS.string] &&
                                (name == "File_tvOs.swift" || name == "File_B.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.macOS.string] &&
                                (name == "File_macOS.swift" || name == "File_C.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.macCatalyst.string] &&
                                (name == "File_MACCATALYST.swift" || name == "File_D.swift") {
                        continue
                    }
                    
                    throw failure("Unexpected source file / destinationFilters")
                }
            }
            
            $0.it("filter sources with destinationFilters") {
                let sourceFile1 = TargetSource(path: "App_supportedDestinations/TestResources/iOs",
                                               destinationFilters: [.iOS])
                let sourceFile2 = TargetSource(path: "App_supportedDestinations/TestResources/TVOS",
                                               destinationFilters: [.tvOS])
                let sourceFile3 = TargetSource(path: "App_supportedDestinations/TestResources/macos",
                                               destinationFilters: [.macOS, .macCatalyst])
                let sourceFile4 = TargetSource(path: "App_supportedDestinations/TestResources/macCatalyst",
                                               destinationFilters: [.macOS, .macCatalyst])
                let sourceFile5 = TargetSource(path: "App_supportedDestinations/TestResources/File_ios.swift",
                                               destinationFilters: [.iOS])
                let sourceFile6 = TargetSource(path: "App_supportedDestinations/TestResources/File_tvOs.swift",
                                               destinationFilters: [.tvOS])
                let sourceFile7 = TargetSource(path: "App_supportedDestinations/TestResources/File_macOS.swift",
                                               destinationFilters: [.macOS, .macCatalyst])
                let sourceFile8 = TargetSource(path: "App_supportedDestinations/TestResources/File_MACCATALYST.swift",
                                               destinationFilters: [.macOS, .macCatalyst])
                
                let target = Target(
                    name: "test",
                    type: .application,
                    platform: .auto,
                    sources: [sourceFile1, sourceFile2, sourceFile3, sourceFile4, sourceFile5, sourceFile6, sourceFile7, sourceFile8],
                    dependencies: []
                )
                
                let project = Project(
                    basePath: fixturePath + "TestProject",
                    name: "test",
                    targets: [target]
                )
                
                let pbxProject = try project.generatePbxProj()
                let buildFiles = pbxProject.buildFiles
                
                try expect(buildFiles.count) == 8
                
                for buildFile in buildFiles {
                    let name = buildFile.file?.nameOrPath
                    
                    if buildFile.platformFilters == [SupportedDestination.iOS.string] &&
                        (name == "File_ios.swift" || name == "File_A.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.tvOS.string] &&
                                (name == "File_tvOs.swift" || name == "File_B.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.macOS.string, SupportedDestination.macCatalyst.string] &&
                                (name == "File_C.swift" || name == "File_D.swift") {
                        continue
                    } else if buildFile.platformFilters == [SupportedDestination.macOS.string, SupportedDestination.macCatalyst.string] &&
                                (name == "File_macOS.swift" || name == "File_MACCATALYST.swift") {
                        continue
                    }
                    
                    throw failure("Unexpected source file / destinationFilters")
                }
            }
            
            $0.it("copies Swift Objective-C Interface Header") {
                let swiftStaticLibraryWithHeader = Target(
                    name: "swiftStaticLibraryWithHeader",
                    type: .staticLibrary,
                    platform: .iOS,
                    sources: [TargetSource(path: "StaticLibrary_Swift/StaticLibrary.swift")],
                    dependencies: []
                )
                let swiftStaticLibraryWithoutHeader1 = Target(
                    name: "swiftStaticLibraryWithoutHeader1",
                    type: .staticLibrary,
                    platform: .iOS,
                    settings: Settings(buildSettings: ["SWIFT_OBJC_INTERFACE_HEADER_NAME": ""]),
                    sources: [TargetSource(path: "StaticLibrary_Swift/StaticLibrary.swift")],
                    dependencies: []
                )
                let swiftStaticLibraryWithoutHeader2 = Target(
                    name: "swiftStaticLibraryWithoutHeader2",
                    type: .staticLibrary,
                    platform: .iOS,
                    settings: Settings(buildSettings: ["SWIFT_INSTALL_OBJC_HEADER": false]),
                    sources: [TargetSource(path: "StaticLibrary_Swift/StaticLibrary.swift")],
                    dependencies: []
                )
                let swiftStaticLibraryWithoutHeader3 = Target(
                    name: "swiftStaticLibraryWithoutHeader3",
                    type: .staticLibrary,
                    platform: .iOS,
                    settings: Settings(buildSettings: ["SWIFT_INSTALL_OBJC_HEADER": "NO"]),
                    sources: [TargetSource(path: "StaticLibrary_Swift/StaticLibrary.swift")],
                    dependencies: []
                )
                let objCStaticLibrary = Target(
                    name: "objCStaticLibrary",
                    type: .staticLibrary,
                    platform: .iOS,
                    sources: [TargetSource(path: "StaticLibrary_ObjC/StaticLibrary_ObjC.m")],
                    dependencies: []
                )

                let targets = [swiftStaticLibraryWithHeader, swiftStaticLibraryWithoutHeader1, swiftStaticLibraryWithoutHeader2, swiftStaticLibraryWithoutHeader3, objCStaticLibrary]

                let project = Project(
                    basePath: fixturePath + "TestProject",
                    name: "test",
                    targets: targets,
                    options: SpecOptions()
                )

                let pbxProject = try project.generatePbxProj()

                func scriptBuildPhases(target: Target) throws -> [PBXShellScriptBuildPhase] {

                    let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == target.name }))
                    let buildPhases = nativeTarget.buildPhases
                    let scriptPhases = buildPhases.compactMap { $0 as? PBXShellScriptBuildPhase }
                    return scriptPhases
                }

                let expectedScriptPhase = PBXShellScriptBuildPhase(
                    name: "Copy Swift Objective-C Interface Header",
                    inputPaths: ["$(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                    outputPaths: ["$(BUILT_PRODUCTS_DIR)/include/$(PRODUCT_MODULE_NAME)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                    shellPath: "/bin/sh",
                    shellScript: "ditto \"${SCRIPT_INPUT_FILE_0}\" \"${SCRIPT_OUTPUT_FILE_0}\"\n"
                )

                try expect(scriptBuildPhases(target: swiftStaticLibraryWithHeader)) == [expectedScriptPhase]
                try expect(scriptBuildPhases(target: swiftStaticLibraryWithoutHeader1)) == []
                try expect(scriptBuildPhases(target: swiftStaticLibraryWithoutHeader2)) == []
                try expect(scriptBuildPhases(target: swiftStaticLibraryWithoutHeader3)) == []
                try expect(scriptBuildPhases(target: objCStaticLibrary)) == []
            }

            $0.it("generates run scripts") {
                var scriptSpec = project
                scriptSpec.targets[0].preBuildScripts = [BuildScript(script: .script("script1"))]
                scriptSpec.targets[0].postCompileScripts = [BuildScript(script: .script("script2"))]
                scriptSpec.targets[0].postBuildScripts = [
                    BuildScript(script: .script("script3")),
                    BuildScript(script: .script("script4"), discoveredDependencyFile: "$(DERIVED_FILE_DIR)/target.d")
                ]
                let pbxProject = try scriptSpec.generatePbxProj()

                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.buildPhases.count >= 4 }))
                let buildPhases = nativeTarget.buildPhases

                let scripts = pbxProject.shellScriptBuildPhases
                try expect(scripts.count) == 4
                let script1 = scripts.first { $0.shellScript == "script1" }!
                let script2 = scripts.first { $0.shellScript == "script2" }!
                let script3 = scripts.first { $0.shellScript == "script3" }!
                let script4 = scripts.first { $0.shellScript == "script4" }!
                try expect(buildPhases.contains(script1)) == true
                try expect(buildPhases.contains(script2)) == true
                try expect(buildPhases.contains(script3)) == true
                try expect(buildPhases.contains(script4)) == true
                try expect(script1.dependencyFile).beNil()
                try expect(script2.dependencyFile).beNil()
                try expect(script3.dependencyFile).beNil()
                try expect(script4.dependencyFile) == "$(DERIVED_FILE_DIR)/target.d"
            }

            $0.it("generates targets with cylical dependencies") {
                let target1 = Target(
                    name: "target1",
                    type: .framework,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: "target2")]
                )
                let target2 = Target(
                    name: "target2",
                    type: .framework,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: "target1")]
                )
                let project = Project(
                    name: "test",
                    targets: [target1, target2]
                )

                _ = try project.generatePbxProj()
            }

            $0.it("generates build rules") {
                var scriptSpec = project
                scriptSpec.targets[0].buildRules = [
                    BuildRule(
                        fileType: .type("sourcecode.swift"),
                        action: .script("do thing"),
                        name: "My Rule",
                        outputFiles: ["file1.swift", "file2.swift"],
                        outputFilesCompilerFlags: ["--zee", "--bee"]
                    ),
                    BuildRule(
                        fileType: .pattern("*.plist"),
                        action: .compilerSpec("com.apple.build-tasks.copy-plist-file")
                    ),
                ]
                let pbxProject = try scriptSpec.generatePbxProj()

                let buildRules = pbxProject.buildRules
                try expect(buildRules.count) == 2
                let first = buildRules.first { $0.name == "My Rule" }!
                let second = buildRules.first { $0.name != "My Rule" }!

                try expect(first.name) == "My Rule"
                try expect(first.isEditable) == true
                try expect(first.outputFiles) == ["file1.swift", "file2.swift"]
                try expect(first.outputFilesCompilerFlags) == ["--zee", "--bee"]
                try expect(first.script) == "do thing"
                try expect(first.fileType) == "sourcecode.swift"
                try expect(first.compilerSpec) == "com.apple.compilers.proxy.script"
                try expect(first.filePatterns).beNil()

                try expect(second.name) == "Build Rule"
                try expect(second.fileType) == "pattern.proxy"
                try expect(second.filePatterns) == "*.plist"
                try expect(second.compilerSpec) == "com.apple.build-tasks.copy-plist-file"
                try expect(second.script).beNil()
                try expect(second.outputFiles) == []
                try expect(second.outputFilesCompilerFlags) == []
            }

            $0.it("generates dependency build file settings") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: "MyFramework"),
                        Dependency(type: .target, reference: "MyOptionalFramework", weakLink: true),
                    ]
                )

                let project = Project(name: "test", targets: [app, framework, optionalFramework, uiTest])
                let pbxProject = try project.generatePbxProj()

                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                let frameworkBuildFiles = frameworkPhases[0].files ?? []
                let buildFileSettings = frameworkBuildFiles.map { $0.settings }

                try expect(frameworkBuildFiles.count) == 2
                try expect(buildFileSettings.compactMap { $0 }.count) == 1
                try expect(buildFileSettings.compactMap { $0?["ATTRIBUTES"] }.count) == 1
                try expect(buildFileSettings.compactMap { $0?["ATTRIBUTES"] as? [String] }.first) == ["Weak"]
            }

            $0.it("generates swift packages") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: ["ProjectSpec"]), reference: "XcodeGen"),
                        Dependency(type: .package(products: []), reference: "Codability"),
                    ]
                )

                let project = Project(name: "test", targets: [app], packages: [
                    "XcodeGen": .remote(url: "http://github.com/yonaskolb/XcodeGen", versionRequirement: .branch("master")),
                    "Codability": .remote(url: "http://github.com/yonaskolb/Codability", versionRequirement: .exact("1.0.0")),
                    "Yams": .local(path: "../Yams", group: nil),
                ], options: .init(localPackagesGroup: "MyPackages"))

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))

                let projectSpecDependency = try unwrap(nativeTarget.packageProductDependencies.first(where: { $0.productName == "ProjectSpec" }))

                try expect(projectSpecDependency.package?.name) == "XcodeGen"
                try expect(projectSpecDependency.package?.versionRequirement) == .branch("master")

                let codabilityDependency = try unwrap(nativeTarget.packageProductDependencies.first(where: { $0.productName == "Codability" }))

                try expect(codabilityDependency.package?.name) == "Codability"
                try expect(codabilityDependency.package?.versionRequirement) == .exact("1.0.0")

                let localPackagesGroup = try unwrap(try pbxProject.getMainGroup().children.first(where: { $0.name == "MyPackages" }) as? PBXGroup)

                let yamsLocalPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../Yams" }))
                try expect(localPackagesGroup.children.contains(yamsLocalPackageFile)) == true
                try expect(yamsLocalPackageFile.lastKnownFileType) == "folder"
            }

            $0.it("generates local swift packages") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: []), reference: "XcodeGen"),
                    ]
                )

                let project = Project(name: "test", targets: [app], packages: ["XcodeGen": .local(path: "../XcodeGen", group: nil)])

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let localPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../XcodeGen" }))
                try expect(localPackageFile.lastKnownFileType) == "folder"
                
                let localPackageReference = try unwrap(pbxProject.rootObject?.localPackages.first)
                try expect(pbxProject.rootObject?.localPackages.count) == 1
                try expect(localPackageReference.relativePath) == "../XcodeGen"

                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                guard let frameworkPhase = frameworkPhases.first else {
                    return XCTFail("frameworkPhases should have more than one")
                }

                guard let file = frameworkPhase.files?.first else {
                    return XCTFail("frameworkPhase should have file")
                }

                try expect(file.product?.productName) == "XcodeGen"
            }
            
            $0.it("generates local swift packages with custom xcode path") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: []), reference: "XcodeGen"),
                    ]
                )

                let customLocalPackageGroup = "Packages/Feature"
                let project = Project(name: "test", targets: [app], packages: ["XcodeGen": .local(path: "../XcodeGen", group: customLocalPackageGroup)])

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let localPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../XcodeGen" }))
                try expect(localPackageFile.lastKnownFileType) == "folder"

                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                let packagesGroup = try unwrap(pbxProject.groups.first(where: { $0.name == "Packages" }))
                let featureGroup = try unwrap(pbxProject.groups.first(where: { $0.name == "Feature" }))

                guard featureGroup.parent?.uuid == packagesGroup.uuid else {
                  return XCTFail("Packages group should be parent of Feature group")
                }

                guard localPackageFile.parent?.uuid == featureGroup.uuid else {
                  return XCTFail("Packages group should be parent of Feature group")
                }

                guard let frameworkPhase = frameworkPhases.first else {
                    return XCTFail("frameworkPhases should have more than one")
                }

                guard let file = frameworkPhase.files?.first else {
                    return XCTFail("frameworkPhase should have file")
                }

                try expect(file.product?.productName) == "XcodeGen"
            }

            $0.it("generates local swift packages at the top level") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: []), reference: "XcodeGen"),
                    ]
                )

                let project = Project(name: "test", targets: [app], packages: ["XcodeGen": .local(path: "../XcodeGen", group: "")])

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let localPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../XcodeGen" }))
                try expect(localPackageFile.lastKnownFileType) == "folder"

                let mainGroup = try pbxProject.getMainGroup()

                try expect(mainGroup.children.contains(localPackageFile)) == true

                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                guard let frameworkPhase = frameworkPhases.first else {
                    return XCTFail("frameworkPhases should have more than one")
                }

                guard let file = frameworkPhase.files?.first else {
                    return XCTFail("frameworkPhase should have file")
                }

                try expect(file.product?.productName) == "XcodeGen"
            }

            $0.it("generates local swift package group at the top level") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: []), reference: "XcodeGen"),
                    ]
                )

                let project = Project(name: "test", targets: [app], packages: ["XcodeGen": .local(path: "../XcodeGen", group: nil)], options: .init(localPackagesGroup: ""))

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let localPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../XcodeGen" }))
                try expect(localPackageFile.lastKnownFileType) == "folder"

                let mainGroup = try pbxProject.getMainGroup()

                try expect(mainGroup.children.contains(localPackageFile)) == true

                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                guard let frameworkPhase = frameworkPhases.first else {
                    return XCTFail("frameworkPhases should have more than one")
                }

                guard let file = frameworkPhase.files?.first else {
                    return XCTFail("frameworkPhase should have file")
                }

                try expect(file.product?.productName) == "XcodeGen"
            }

            $0.it("generates info.plist") {
                let plist = Plist(path: "Info.plist", attributes: ["UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft"]])
                let tempPath = Path.temporary + "info"
                let project = Project(basePath: tempPath, name: "", targets: [Target(name: "", type: .application, platform: .iOS, info: plist)])
                let pbxProject = try project.generatePbxProj()
                let writer = FileWriter(project: project)
                try writer.writePlists()

                let targetConfig = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)

                try expect(targetConfig.buildSettings["INFOPLIST_FILE"] as? String) == plist.path

                let infoPlistFile = tempPath + plist.path
                let data: Data = try infoPlistFile.read()
                let infoPlist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
                let expectedInfoPlist: [String: Any] = [
                    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                    "CFBundleInfoDictionaryVersion": "6.0",
                    "CFBundleName": "$(PRODUCT_NAME)",
                    "CFBundleExecutable": "$(EXECUTABLE_NAME)",
                    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                    "CFBundleShortVersionString": "1.0",
                    "CFBundleVersion": "1",
                    "CFBundlePackageType": "APPL",
                    "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft"],
                ]

                try expect(NSDictionary(dictionary: expectedInfoPlist).isEqual(to: infoPlist)).beTrue()
            }

            $0.it("info doesn't override info.plist setting") {
                let predefinedPlistPath = "Predefined.plist"
                // generate plist
                let plist = Plist(path: "Info.plist", attributes: ["UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft"]])
                let tempPath = Path.temporary + "info"
                // create project with a predefined plist
                let project = Project(basePath: tempPath, name: "", targets: [Target(name: "", type: .application, platform: .iOS, settings: Settings(buildSettings: ["INFOPLIST_FILE": predefinedPlistPath]), info: plist)])
                let pbxProject = try project.generatePbxProj()
                let writer = FileWriter(project: project)
                try writer.writePlists()

                let targetConfig = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)
                // generated plist should not be in buildsettings
                try expect(targetConfig.buildSettings["INFOPLIST_FILE"] as? String) == predefinedPlistPath
            }

            describe("Carthage dependencies") {
                $0.context("with static dependency") {
                    $0.it("should set dependencies") {
                        let app = Target(
                            name: "MyApp",
                            type: .application,
                            platform: .iOS,
                            dependencies: [
                                Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "MyStaticFramework"),
                            ]
                        )
                        let project = Project(name: "test", targets: [app])
                        let pbxProject = try project.generatePbxProj()

                        let target = pbxProject.nativeTargets.first!
                        let configuration = target.buildConfigurationList!.buildConfigurations.first!
                        try expect(configuration.buildSettings["FRAMEWORK_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "$(PROJECT_DIR)/Carthage/Build/iOS/Static"]
                        let frameworkBuildPhase = try target.frameworksBuildPhase()
                        guard let files = frameworkBuildPhase?.files, let file = files.first else {
                            return XCTFail("frameworkBuildPhase should have files")
                        }
                        try expect(files.count) == 1
                        try expect(file.file?.nameOrPath) == "MyStaticFramework.framework"

                        try expect(target.carthageCopyFrameworkBuildPhase).beNil()
                    }
                }

                $0.context("with mixed dependencies") {
                    $0.it("should set dependencies") {
                        let app = Target(
                            name: "MyApp",
                            type: .application,
                            platform: .iOS,
                            dependencies: [
                                Dependency(type: .carthage(findFrameworks: true, linkType: .dynamic), reference: "MyDynamicFramework"),
                                Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "MyStaticFramework"),
                            ]
                        )
                        let project = Project(name: "test", targets: [app])
                        let pbxProject = try project.generatePbxProj()

                        let target = pbxProject.nativeTargets.first!
                        let configuration = target.buildConfigurationList!.buildConfigurations.first!
                        try expect(configuration.buildSettings["FRAMEWORK_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "$(PROJECT_DIR)/Carthage/Build/iOS", "$(PROJECT_DIR)/Carthage/Build/iOS/Static"]
                        let frameworkBuildPhase = try target.frameworksBuildPhase()
                        guard let files = frameworkBuildPhase?.files else {
                            return XCTFail("frameworkBuildPhase should have files")
                        }
                        try expect(files.count) == 2

                        guard let dynamicFramework = files.first(where: { $0.file?.nameOrPath == "MyDynamicFramework.framework" }) else {
                            return XCTFail("Framework Build Phase should have Dynamic Framework")
                        }
                        guard let _ = files.first(where: { $0.file?.nameOrPath == "MyStaticFramework.framework" }) else {
                            return XCTFail("Framework Build Phase should have Static Framework")
                        }

                        guard let copyCarthagePhase = target.carthageCopyFrameworkBuildPhase else {
                            return XCTFail("Carthage Build Phase should be exist")
                        }
                        try expect(copyCarthagePhase.inputPaths) == [dynamicFramework.file?.fullPath(sourceRoot: Path("$(SRCROOT)"))?.string]
                        try expect(copyCarthagePhase.outputPaths) == ["$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\(dynamicFramework.file!.path!)"]
                    }
                }
            }

            $0.it("generate info.plist doesn't generate CFBundleExecutable for targets with type bundle") {
                let plist = Plist(path: "Info.plist", attributes: [:])
                let tempPath = Path.temporary + "info"
                let project = Project(basePath: tempPath, name: "", targets: [Target(name: "", type: .bundle, platform: .iOS, info: plist)])
                let pbxProject = try project.generatePbxProj()
                let writer = FileWriter(project: project)
                try writer.writePlists()

                let targetConfig = try unwrap(pbxProject.nativeTargets.first?.buildConfigurationList?.buildConfigurations.first)

                try expect(targetConfig.buildSettings["INFOPLIST_FILE"] as? String) == plist.path

                let infoPlistFile = tempPath + plist.path
                let data: Data = try infoPlistFile.read()
                let infoPlist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as! [String: Any]
                let expectedInfoPlist: [String: Any] = [
                    "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)",
                    "CFBundleInfoDictionaryVersion": "6.0",
                    "CFBundleName": "$(PRODUCT_NAME)",
                    "CFBundleDevelopmentRegion": "$(DEVELOPMENT_LANGUAGE)",
                    "CFBundleShortVersionString": "1.0",
                    "CFBundleVersion": "1",
                    "CFBundlePackageType": "BNDL",
                ]

                try expect(NSDictionary(dictionary: expectedInfoPlist).isEqual(to: infoPlist)).beTrue()
            }

            $0.it("generates local swift packages with multiple products") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: ["FooDomain", "FooUI"]), reference: "FooFeature")
                    ]
                )

                let project = Project(name: "test", targets: [app], packages: [
                    "FooFeature": .local(path: "../FooFeature", group: nil)
                ], options: .init(localPackagesGroup: "MyPackages"))

                let pbxProject = try project.generatePbxProj(specValidate: false)
                let nativeTarget = try unwrap(pbxProject.nativeTargets.first(where: { $0.name == app.name }))
                let localPackageFile = try unwrap(pbxProject.fileReferences.first(where: { $0.path == "../FooFeature" }))
                try expect(localPackageFile.lastKnownFileType) == "folder"

                let frameworkPhases = nativeTarget.buildPhases.compactMap { $0 as? PBXFrameworksBuildPhase }

                guard let frameworkPhase = frameworkPhases.first else {
                    return XCTFail("frameworkPhases should have more than one")
                }

                guard let files = frameworkPhase.files, files.count == 2 else {
                    return XCTFail("frameworkPhase should have exactly two files")
                }

                let productNames = files.compactMap(\.product?.productName)
                try expect(productNames).contains { $0 == "FooDomain" }
                try expect(productNames).contains { $0 == "FooUI" }
            }
        }
    }

    func testGenerateXcodeProjectWithDestination() throws {
        let groupName = "App_iOS"
        let sourceDirectory = fixturePath + "TestProject" + groupName
        let frameworkWithSources = Target(
            name: "MyFramework",
            type: .framework,
            platform: .iOS,
            sources: [TargetSource(path: sourceDirectory.string)]
        )

        describe("generateXcodeProject") {
            $0.context("without projectDirectory") {
                $0.it("generate groups") {
                    let project = Project(name: "test", targets: [frameworkWithSources])
                    let generator = ProjectGenerator(project: project)
                    let generatedProject = try generator.generateXcodeProject(userName: "someUser")
                    let group = generatedProject.pbxproj.groups.first(where: { $0.nameOrPath == groupName })
                    try expect(group?.path) == "App_iOS"
                }
            }

            $0.context("with projectDirectory") {
                $0.it("generate groups") {
                    let destinationPath = fixturePath
                    let project = Project(name: "test", targets: [frameworkWithSources])
                    let generator = ProjectGenerator(project: project)
                    let generatedProject = try generator.generateXcodeProject(in: destinationPath, userName: "someUser")
                    let group = generatedProject.pbxproj.groups.first(where: { $0.nameOrPath == groupName })
                    try expect(group?.path) == "TestProject/App_iOS"
                }

                $0.it("generate Info.plist") {
                    let destinationPath = fixturePath
                    let project = Project(name: "test", targets: [frameworkWithSources])
                    let generator = ProjectGenerator(project: project)
                    let generatedProject = try generator.generateXcodeProject(in: destinationPath, userName: "someUser")
                    let plists = generatedProject.pbxproj.buildConfigurations.compactMap { $0.buildSettings["INFOPLIST_FILE"] as? String }
                    try expect(plists.count) == 2
                    for plist in plists {
                        try expect(plist) == "TestProject/App_iOS/Info.plist"
                    }
                }
            }

            describe("Carthage dependencies") {
                $0.context("with static dependency") {
                    $0.it("should set dependencies") {
                        let app = Target(
                            name: "MyApp",
                            type: .application,
                            platform: .iOS,
                            dependencies: [
                                Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "MyStaticFramework"),
                            ]
                        )
                        let project = Project(name: "test", targets: [app])
                        let pbxProject = try project.generatePbxProj()

                        let target = pbxProject.nativeTargets.first!
                        let configuration = target.buildConfigurationList!.buildConfigurations.first!
                        try expect(configuration.buildSettings["FRAMEWORK_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "$(PROJECT_DIR)/Carthage/Build/iOS/Static"]
                        let frameworkBuildPhase = try target.frameworksBuildPhase()
                        guard let files = frameworkBuildPhase?.files, let file = files.first else {
                            return XCTFail("frameworkBuildPhase should have files")
                        }
                        try expect(files.count) == 1
                        try expect(file.file?.nameOrPath) == "MyStaticFramework.framework"

                        try expect(target.carthageCopyFrameworkBuildPhase).beNil()
                    }
                }

                $0.context("with mixed dependencies") {
                    $0.it("should set dependencies") {
                        let app = Target(
                            name: "MyApp",
                            type: .application,
                            platform: .iOS,
                            dependencies: [
                                Dependency(type: .carthage(findFrameworks: true, linkType: .dynamic), reference: "MyDynamicFramework"),
                                Dependency(type: .carthage(findFrameworks: true, linkType: .static), reference: "MyStaticFramework"),
                            ]
                        )
                        let project = Project(name: "test", targets: [app])
                        let pbxProject = try project.generatePbxProj()

                        let target = pbxProject.nativeTargets.first!
                        let configuration = target.buildConfigurationList!.buildConfigurations.first!

                        try expect(configuration.buildSettings["FRAMEWORK_SEARCH_PATHS"] as? [String]) == ["$(inherited)", "$(PROJECT_DIR)/Carthage/Build/iOS", "$(PROJECT_DIR)/Carthage/Build/iOS/Static"]

                        let frameworkBuildPhase = try target.frameworksBuildPhase()
                        guard let files = frameworkBuildPhase?.files else {
                            return XCTFail("frameworkBuildPhase should have files")
                        }
                        try expect(files.count) == 2

                        guard let dynamicFramework = files.first(where: { $0.file?.nameOrPath == "MyDynamicFramework.framework" }) else {
                            return XCTFail("Framework Build Phase should have Dynamic Framework")
                        }
                        guard let _ = files.first(where: { $0.file?.nameOrPath == "MyStaticFramework.framework" }) else {
                            return XCTFail("Framework Build Phase should have Static Framework")
                        }

                        guard let copyCarthagePhase = target.carthageCopyFrameworkBuildPhase else {
                            return XCTFail("Carthage Build Phase should be exist")
                        }
                        try expect(copyCarthagePhase.inputPaths) == [dynamicFramework.file?.fullPath(sourceRoot: Path("$(SRCROOT)"))?.string]
                        try expect(copyCarthagePhase.outputPaths) == ["$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\(dynamicFramework.file!.path!)"]
                    }
                }
            }
        }
    }
    
    func testGenerateXcodeProjectWithPlatformFilteredDependencies() throws {
        
        describe("generateXcodeProject with destinationFilters") {
            
            func generateProjectForApp(withDependencies: [Dependency], targets: [Target], packages: [String: SwiftPackage] = [:]) throws -> PBXProj {
                
                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .iOS,
                    dependencies: withDependencies
                )
                
                let project = Project(
                    name: "test",
                    targets: targets + [app],
                    packages: packages
                )
                
                return try project.generatePbxProj()
            }
            
            func expectLinkedDependecies(_ expectedLinkedFiles: [String: [String]], in project: PBXProj) throws {
                let buildPhases = project.buildPhases
                let frameworkPhases = project.frameworksBuildPhases.filter { buildPhases.contains($0) }
                
                var linkedFiles: [String: [String]] = [:]
                
                for link in frameworkPhases[0].files ?? [] {
                    if let name = link.file?.nameOrPath ?? link.product?.productName  {
                        linkedFiles[name] = link.platformFilters
                    }
                }
                
                try expect(linkedFiles) == expectedLinkedFiles
            }
            
            func expectCopiedBundles(_ expectedCopiedBundleFiles: [String: [String]], in project: PBXProj) throws {
                let buildPhases = project.buildPhases
                let copyBundlesPhase = project.copyFilesBuildPhases.filter { buildPhases.contains($0) }
                
                var copiedFiles: [String: [String]] = [:]
                
                for copy in copyBundlesPhase[0].files ?? [] {
                    if let name = copy.file?.nameOrPath {
                        copiedFiles[name] = copy.platformFilters
                    }
                }
                
                try expect(copiedFiles) == expectedCopiedBundleFiles
            }
            
            $0.it("target dependencies") {
                
                let frameworkA = Target(
                    name: "frameworkA",
                    type: .framework,
                    platform: .iOS
                )
                
                let frameworkB = Target(
                    name: "frameworkB",
                    type: .framework,
                    platform: .iOS
                )
                
                let expectedLinkedFiles = [
                    "frameworkA.framework": [SupportedDestination.iOS.string],
                    "frameworkB.framework": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .target, reference: frameworkA.name, destinationFilters: [.iOS]),
                    Dependency(type: .target, reference: frameworkB.name, destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                
                // then ensure that everything is linked
                try expectLinkedDependecies(expectedLinkedFiles, in: pbxProject)
            }
            
            $0.it("framework dependencies") {
                
                let expectedLinkedFiles = [
                    "frameworkA.framework": [SupportedDestination.iOS.string],
                    "frameworkB.framework": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .framework, reference: "frameworkA.framework", destinationFilters: [.iOS]),
                    Dependency(type: .framework, reference: "frameworkB.framework", destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                
                // then ensure that everything is linked
                try expectLinkedDependecies(expectedLinkedFiles, in: pbxProject)
            }
            
            $0.it("carthage dependencies") {
                
                let expectedLinkedFiles = [
                    "frameworkA.framework": [SupportedDestination.iOS.string],
                    "frameworkB.framework": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "frameworkA.framework", destinationFilters: [.iOS]),
                    Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "frameworkB.framework", destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                
                // then ensure that everything is linked
                try expectLinkedDependecies(expectedLinkedFiles, in: pbxProject)
            }
            
            $0.it("sdk dependencies") {
                
                let expectedLinkedFiles = [
                    "sdkA.framework": [SupportedDestination.iOS.string],
                    "sdkB.framework": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .sdk(root: nil), reference: "sdkA.framework", destinationFilters: [.iOS]),
                    Dependency(type: .sdk(root: nil), reference: "sdkB.framework", destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                
                // then ensure that everything is linked
                try expectLinkedDependecies(expectedLinkedFiles, in: pbxProject)
            }
            
            $0.it("package dependencies") {
                
                let packages: [String: SwiftPackage] = [
                    "RxSwift": .remote(url: "https://github.com/ReactiveX/RxSwift", versionRequirement: .upToNextMajorVersion("5.1.1")),
                ]
                
                let expectedLinkedFiles = [
                    "RxSwift": [SupportedDestination.iOS.string],
                    "RxCocoa": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .package(products: ["RxSwift"]), reference: "RxSwift", destinationFilters: [.iOS]),
                    Dependency(type: .package(products: ["RxCocoa"]), reference: "RxSwift", destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [], packages: packages)
                
                // then ensure that everything is linked
                try expectLinkedDependecies(expectedLinkedFiles, in: pbxProject)
            }
            
            $0.it("bundle dependencies") {
                
                let expectedCopiedBundleFiles = [
                    "bundleA.bundle": [SupportedDestination.iOS.string],
                    "bundleB.bundle": [SupportedDestination.iOS.string, SupportedDestination.tvOS.string]
                ]
                
                // given
                let dependencies = [
                    Dependency(type: .bundle, reference: "bundleA.bundle", destinationFilters: [.iOS]),
                    Dependency(type: .bundle, reference: "bundleB.bundle", destinationFilters: [.iOS, .tvOS]),
                ]
                
                // when
                let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                
                // then ensure that everything is linked
                try expectCopiedBundles(expectedCopiedBundleFiles, in: pbxProject)
            }
        }
    }
    
    func testGenerateXcodeProjectWithCustomDependencyDestinations() throws {
        
        describe("generateXcodeProject") {
            
            func generateProjectForApp(withDependencies: [Dependency], targets: [Target], packages: [String: SwiftPackage] = [:]) throws -> PBXProj {
                
                let app = Target(
                    name: "App",
                    type: .application,
                    platform: .macOS,
                    dependencies: withDependencies
                )
                
                let project = Project(
                    name: "test",
                    targets: targets + [app],
                    packages: packages
                )

                return try project.generatePbxProj()
            }
            
            func expectCopyPhase(in project:PBXProj, withFilePaths: [String]? = nil, withProductPaths: [String]? = nil, toSubFolder subfolder: PBXCopyFilesBuildPhase.SubFolder, dstPath: String? = nil) throws {
                
                let phases = project.copyFilesBuildPhases
                try expect(phases.count) == 1
                let phase = phases.first!
                try expect(phase.dstSubfolderSpec) == subfolder
                try expect(phase.dstPath) == dstPath
                if let paths = withFilePaths {
                    try expect(phase.files?.count) == paths.count
                    let filePaths = phase.files!.map { $0.file!.path }
                    try expect(filePaths) == paths
                }
                if let paths = withProductPaths {
                    try expect(phase.files?.count) == paths.count
                    let filePaths = phase.files!.map { $0.product!.productName }
                    try expect(filePaths) == paths
                }
            }
            
            $0.context("with target dependencies") {
                $0.context("application") {
                    
                    let appA = Target(
                        name: "appA",
                        type: .application,
                        platform: .macOS
                    )
                    let appB = Target(
                        name: "appB",
                        type: .application,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true),
                            Dependency(type: .target, reference: appB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [ appA, appB ])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: appB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["appA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("framework") {
                    
                    let frameworkA = Target(
                        name: "frameworkA",
                        type: .framework,
                        platform: .macOS
                    )
                    let frameworkB = Target(
                        name: "frameworkB",
                        type: .framework,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into frameworks without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true),
                            Dependency(type: .target, reference: frameworkB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .frameworks, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: frameworkB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("staticFramework") {
                    
                    let frameworkA = Target(
                        name: "frameworkA",
                        type: .staticFramework,
                        platform: .macOS
                    )
                    let frameworkB = Target(
                        name: "frameworkB",
                        type: .staticFramework,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into frameworks without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true),
                            Dependency(type: .target, reference: frameworkB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .frameworks, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: frameworkB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("xcFramework") {
                    
                    let frameworkA = Target(
                        name: "frameworkA",
                        type: .xcFramework,
                        platform: .macOS
                    )
                    let frameworkB = Target(
                        name: "frameworkB",
                        type: .xcFramework,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true),
                            Dependency(type: .target, reference: frameworkB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: frameworkA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: frameworkB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [frameworkA, frameworkB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.xcframework"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("Dynamic Library") {
                    
                    let libraryA = Target(
                        name: "libraryA",
                        type: .dynamicLibrary,
                        platform: .macOS
                    )
                    let libraryB = Target(
                        name: "libraryB",
                        type: .dynamicLibrary,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true),
                            Dependency(type: .target, reference: libraryB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: libraryB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["libraryA.dylib"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("Static Library") {
                    
                    let libraryA = Target(
                        name: "libraryA",
                        type: .staticLibrary,
                        platform: .macOS
                    )
                    let libraryB = Target(
                        name: "libraryB",
                        type: .staticLibrary,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true),
                            Dependency(type: .target, reference: libraryB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them to custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: libraryB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["liblibraryA.a"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("bundle") {
                    
                    let bundleA = Target(
                        name: "bundleA",
                        type: .bundle,
                        platform: .macOS
                    )
                    let bundleB = Target(
                        name: "bundleB",
                        type: .bundle,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true),
                            Dependency(type: .target, reference: bundleB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: bundleB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.bundle"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("unitTestBundle") {
                    
                    let bundleA = Target(
                        name: "bundleA",
                        type: .unitTestBundle,
                        platform: .macOS
                    )
                    let bundleB = Target(
                        name: "bundleB",
                        type: .unitTestBundle,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true),
                            Dependency(type: .target, reference: bundleB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: bundleB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.xctest"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
            
                $0.context("uitTestBundle") {
                    
                    let bundleA = Target(
                        name: "bundleA",
                        type: .uiTestBundle,
                        platform: .macOS
                    )
                    let bundleB = Target(
                        name: "bundleB",
                        type: .uiTestBundle,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true),
                            Dependency(type: .target, reference: bundleB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: bundleB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.xctest"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("appExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .appExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .appExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .executables, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .executables, subpath: "test", phaseOrder: .postCompile)),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .executables, dstPath: "test")
                    }
                }

                $0.context("extensionKit") {

                    let extA = Target(
                        name: "extA",
                        type: .extensionKitExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .extensionKitExtension,
                        platform: .macOS
                    )

                    $0.it("embeds them into plugins without copy phase spec") {

                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])

                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .productsDirectory, dstPath: "$(EXTENSIONS_FOLDER_PATH)")
                    }

                    $0.it("embeds them into custom location with copy phase spec") {

                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .productsDirectory, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .productsDirectory, subpath: "test", phaseOrder: .postCompile)),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])

                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .productsDirectory, dstPath: "test")
                    }
                }
                
                $0.context("commandLineTool") {
                    
                    let toolA = Target(
                        name: "toolA",
                        type: .commandLineTool,
                        platform: .macOS
                    )
                    let toolB = Target(
                        name: "toolB",
                        type: .commandLineTool,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: toolA.name, embed: true),
                            Dependency(type: .target, reference: toolB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [toolA, toolB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: toolA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: toolB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [toolA, toolB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["toolA"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("watchApp") {
                    
                    let appA = Target(
                        name: "appA",
                        type: .watchApp,
                        platform: .macOS
                    )
                    let appB = Target(
                        name: "appB",
                        type: .watchApp,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true),
                            Dependency(type: .target, reference: appB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: appB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["appA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("watch2App") {
                    
                    let appA = Target(
                        name: "appA",
                        type: .watch2App,
                        platform: .macOS
                    )
                    let appB = Target(
                        name: "appB",
                        type: .watch2App,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true),
                            Dependency(type: .target, reference: appB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: appB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["appA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("watch2AppContainer") {
                    
                    let appA = Target(
                        name: "appA",
                        type: .watch2AppContainer,
                        platform: .macOS
                    )
                    let appB = Target(
                        name: "appB",
                        type: .watch2AppContainer,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true),
                            Dependency(type: .target, reference: appB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: appB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["appA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("watchExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .watchExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .watchExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("watch2Extension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .watch2Extension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .watch2Extension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("tvExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .tvExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .tvExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("messagesApplication") {
                    
                    let appA = Target(
                        name: "appA",
                        type: .messagesApplication,
                        platform: .macOS
                    )
                    let appB = Target(
                        name: "appB",
                        type: .messagesApplication,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true),
                            Dependency(type: .target, reference: appB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: appA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: appB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [appA, appB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["appA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("messagesExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .messagesExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .messagesExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("stickerPack") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .stickerPack,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .stickerPack,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("xpcService") {
                    
                    let xpcA = Target(
                        name: "xpcA",
                        type: .xpcService,
                        platform: .macOS
                    )
                    let xpcB = Target(
                        name: "xpcB",
                        type: .xpcService,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: xpcA.name, embed: true),
                            Dependency(type: .target, reference: xpcB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [xpcA, xpcB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["xpcA.xpc"], toSubFolder: .productsDirectory, dstPath: "$(CONTENTS_FOLDER_PATH)/XPCServices")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: xpcA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: xpcB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [xpcA, xpcB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["xpcA.xpc"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("ocUnitTestBundle") {
                    
                    let bundleA = Target(
                        name: "bundleA",
                        type: .ocUnitTestBundle,
                        platform: .macOS
                    )
                    let bundleB = Target(
                        name: "bundleB",
                        type: .ocUnitTestBundle,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true),
                            Dependency(type: .target, reference: bundleB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: bundleA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: bundleB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [bundleA, bundleB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.octest"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("xcodeExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .xcodeExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .xcodeExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("instrumentsPackage") {
                    
                    let pkgA = Target(
                        name: "pkgA",
                        type: .instrumentsPackage,
                        platform: .macOS
                    )
                    let pkgB = Target(
                        name: "pkgB",
                        type: .instrumentsPackage,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: pkgA.name, embed: true),
                            Dependency(type: .target, reference: pkgB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [pkgA, pkgB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: pkgA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: pkgB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [pkgA, pkgB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["pkgA.instrpkg"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("intentsServiceExtension") {
                    
                    let extA = Target(
                        name: "extA",
                        type: .intentsServiceExtension,
                        platform: .macOS
                    )
                    let extB = Target(
                        name: "extB",
                        type: .intentsServiceExtension,
                        platform: .macOS
                    )
                    
                    $0.it("embeds them into plugins without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true),
                            Dependency(type: .target, reference: extB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .plugins, dstPath: "")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: extA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: extB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .frameworks, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [extA, extB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["extA.appex"], toSubFolder: .frameworks, dstPath: "test")
                    }
                }
                
                $0.context("appClip") {
                    
                    let clipA = Target(
                        name: "clipA",
                        type: .onDemandInstallCapableApplication,
                        platform: .macOS
                    )
                    let clipB = Target(
                        name: "clipB",
                        type: .onDemandInstallCapableApplication,
                        platform: .macOS
                    )
                    
                    $0.it("does embed them into products directory without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: clipA.name, embed: true),
                            Dependency(type: .target, reference: clipB.name, embed: false),
                        ]

                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [clipA, clipB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["clipA.app"], toSubFolder: .productsDirectory, dstPath: "$(CONTENTS_FOLDER_PATH)/AppClips")
                    }
                    
                    $0.it("embeds them into custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: clipA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: clipB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [clipA, clipB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["clipA.app"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
                
                $0.context("Metal Library") {
                    
                    let libraryA = Target(
                        name: "libraryA",
                        type: .metalLibrary,
                        platform: .macOS
                    )
                    let libraryB = Target(
                        name: "libraryB",
                        type: .metalLibrary,
                        platform: .macOS
                    )
                    
                    $0.it("does not embed them without copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true),
                            Dependency(type: .target, reference: libraryB.name, embed: false),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expect(pbxProject.copyFilesBuildPhases.count) == 0
                    }
                    
                    $0.it("embeds them to custom location with copy phase spec") {
                        
                        // given
                        let dependencies = [
                            Dependency(type: .target, reference: libraryA.name, embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                            Dependency(type: .target, reference: libraryB.name, embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        ]
                        
                        // when
                        let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [libraryA, libraryB])
                        
                        // then
                        try expectCopyPhase(in: pbxProject, withFilePaths: ["libraryA.metallib"], toSubFolder: .plugins, dstPath: "test")
                    }
                }
            }
            
            $0.context("with framework dependencies") {
                $0.it("embeds them into frameworks without copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .framework, reference: "frameworkA.framework", embed: true),
                        Dependency(type: .framework, reference: "frameworkB.framework", embed: false),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .frameworks, dstPath: "")
                }
                
                $0.it("embeds them into custom location with copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .framework, reference: "frameworkA.framework", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .framework, reference: "frameworkB.framework", embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .plugins, dstPath: "test")
                }
                
                $0.it("generates single copy phase for multiple frameworks with same copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .framework, reference: "frameworkA.framework", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .framework, reference: "frameworkB.framework", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework", "frameworkB.framework"], toSubFolder: .plugins, dstPath: "test")
                }
            }
            
            $0.context("with sdk dependencies") {
                
                $0.it("embeds them into frameworks without copy phase spec") {

                    // given
                    let dependencies = [
                        Dependency(type: .sdk(root: nil), reference: "sdkA.framework", embed: true),
                        Dependency(type: .sdk(root: nil), reference: "sdkB.framework", embed: false),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["System/Library/Frameworks/sdkA.framework"], toSubFolder: .frameworks, dstPath: "")
                }
                
                $0.it("embeds them into custom location with copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .sdk(root: nil), reference: "sdkA.framework", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .sdk(root: nil), reference: "sdkB.framework", embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["System/Library/Frameworks/sdkA.framework"], toSubFolder: .plugins, dstPath: "test")
                }
            }
            
            $0.context("with package dependencies") {
                
                let packages: [String: SwiftPackage] = [
                    "RxSwift": .remote(url: "https://github.com/ReactiveX/RxSwift", versionRequirement: .upToNextMajorVersion("5.1.1")),
                ]
                
                $0.it("embeds them into frameworks without copy phase spec") {

                    // given
                    let dependencies = [
                        Dependency(type: .package(products: ["RxSwift"]), reference: "RxSwift", embed: true),
                        Dependency(type: .package(products: ["RxCocoa"]), reference: "RxSwift", embed: false),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [], packages: packages)
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withProductPaths: ["RxSwift"], toSubFolder: .frameworks, dstPath: "")
                }
                
                $0.it("embeds them into custom location with copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .package(products: ["RxSwift"]), reference: "RxSwift", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .package(products: ["RxCocoa"]), reference: "RxSwift", embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [], packages: packages)
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withProductPaths: ["RxSwift"], toSubFolder: .plugins, dstPath: "test")
                }
            }
            
            $0.context("with carthage dependencies") {
                
                $0.it("embeds them into frameworks without copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "frameworkA.framework", embed: true),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "frameworkB.framework", embed: false),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .frameworks, dstPath: "")
                }
                
                $0.it("embeds them into custom location with copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "frameworkA.framework", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .carthage(findFrameworks: false, linkType: .static), reference: "frameworkB.framework", embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["frameworkA.framework"], toSubFolder: .plugins, dstPath: "test")
                }
            }
            
            $0.context("with bundle dependencies") {
                $0.it("embeds them into resources without copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .bundle, reference: "bundleA.bundle", embed: true),
                        Dependency(type: .bundle, reference: "bundleB.bundle", embed: false),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    /// XcodeGen ignores embed: false for bundles
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.bundle", "bundleB.bundle"], toSubFolder: .resources)
                }
                
                $0.it("ignores custom copy phase spec") {
                    
                    // given
                    let dependencies = [
                        Dependency(type: .bundle, reference: "bundleA.bundle", embed: true, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                        Dependency(type: .bundle, reference: "bundleB.bundle", embed: false, copyPhase: BuildPhaseSpec.CopyFilesSettings(destination: .plugins, subpath: "test", phaseOrder: .postCompile)),
                    ]
                    
                    // when
                    let pbxProject = try generateProjectForApp(withDependencies: dependencies, targets: [])
                    
                    // then
                    /// XcodeGen ignores embed: false for bundles
                    try expectCopyPhase(in: pbxProject, withFilePaths: ["bundleA.bundle", "bundleB.bundle"], toSubFolder: .resources)
                }
            }
        }
    }
}

private extension PBXTarget {
    var carthageCopyFrameworkBuildPhase: PBXShellScriptBuildPhase? {
        buildPhases.first(where: { $0.name() == "Carthage" }) as? PBXShellScriptBuildPhase
    }
}
