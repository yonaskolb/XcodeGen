import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcproj
import XCTest
import Yams

fileprivate let app = Target(
    name: "MyApp",
    type: .application,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyFramework")]
)

fileprivate let framework = Target(
    name: "MyFramework",
    type: .framework,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
)

fileprivate let uiTest = Target(
    name: "MyAppUITests",
    type: .uiTestBundle,
    platform: .iOS,
    settings: Settings(buildSettings: ["SETTING_3": "VALUE"]),
    dependencies: [Dependency(type: .target, reference: "MyApp")]
)

fileprivate let targets = [app, framework, uiTest]

class ProjectGeneratorTests: XCTestCase {

    func testOptions() throws {

        describe {

            $0.it("generates bundle id") {
                let options = SpecOptions(bundleIdPrefix: "com.test")
                let project = Project(basePath: "", name: "test", targets: [framework], options: options)
                let pbxProj = try project.generatePbxProj()
                guard let target = pbxProj.objects.nativeTargets.first?.value,
                    let buildConfigList = target.buildConfigurationList,
                    let buildConfigs = pbxProj.objects.configurationLists.getReference(buildConfigList),
                    let buildConfigReference = buildConfigs.buildConfigurations.first,
                    let buildConfig = pbxProj.objects.buildConfigurations.getReference(buildConfigReference) else {
                    throw failure("Build Config not found")
                }
                try expect(buildConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String) == "com.test.MyFramework"
            }

            $0.it("clears setting presets") {
                let options = SpecOptions(settingPresets: .none)
                let project = Project(basePath: "", name: "test", targets: [framework], options: options)
                let pbxProj = try project.generatePbxProj()
                let allSettings = pbxProj.objects.buildConfigurations.referenceValues.reduce([:]) { $0.merged($1.buildSettings) }.keys.sorted()
                try expect(allSettings) == ["SETTING_2"]
            }

            $0.it("generates development language") {
                let options = SpecOptions(developmentLanguage: "de")
                let project = Project(basePath: "", name: "test", options: options)
                let pbxProj = try project.generatePbxProj()
                guard let pbxProject = pbxProj.objects.projects.first?.value else {
                    throw failure("Could't find PBXProject")
                }
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
                let project = Project(basePath: "", name: "test", configs: [Config(name: "Aconfig"), Config(name: "Bconfig")], targets: [framework], options: options)
                let pbxProject = try project.generatePbxProj()

                guard let projectConfigListReference = pbxProject.objects.projects.values.first?.buildConfigurationList,
                    let defaultConfigurationName = pbxProject.objects.configurationLists[projectConfigListReference]?.defaultConfigurationName
                else {
                    throw failure("Default configuration name not found")
                }

                try expect(defaultConfigurationName) == "Bconfig"
            }
        }
    }

    func testConfigGenerator() {
        describe {

            $0.it("generates config defaults") {
                let project = Project(basePath: "", name: "test")
                let pbxProj = try project.generatePbxProj()
                let configs = pbxProj.objects.buildConfigurations.referenceValues
                try expect(configs.count) == 2
                try expect(configs).contains(name: "Debug")
                try expect(configs).contains(name: "Release")
            }

            $0.it("generates configs") {
                let project = Project(
                    basePath: "",
                    name: "test",
                    configs: [Config(name: "config1"), Config(name: "config2")]
                )
                let pbxProj = try project.generatePbxProj()
                let configs = pbxProj.objects.buildConfigurations.referenceValues
                try expect(configs.count) == 2
                try expect(configs).contains(name: "config1")
                try expect(configs).contains(name: "config2")
            }

            $0.it("clears config settings when missing type") {
                let project = Project(
                    basePath: "",
                    name: "test",
                    configs: [Config(name: "config")]
                )
                let pbxProj = try project.generatePbxProj()
                guard let config = pbxProj.objects.buildConfigurations.first?.value else {
                    throw failure("configuration not found")
                }
                try expect(config.buildSettings.isEmpty).to.beTrue()
            }

            $0.it("merges settings") {
                let project = try Project(path: fixturePath + "settings_test.yml")
                guard let config = project.getConfig("config1") else { throw failure("Couldn't find config1") }
                let debugProjectSettings = project.getProjectBuildSettings(config: config)

                guard let target = project.getTarget("Target") else { throw failure("Couldn't find Target") }
                let targetDebugSettings = project.getTargetBuildSettings(target: target, config: config)

                var buildSettings = BuildSettings()
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
                    basePath: "",
                    name: "test",
                    configs: [
                        Config(name: "Staging Debug", type: .debug),
                        Config(name: "Staging Release", type: .release),
                    ],
                    settings: Settings(configSettings: ["staging": ["SETTING1": "VALUE1"], "debug": ["SETTING2": "VALUE2"]])
                )

                var buildSettings = project.getProjectBuildSettings(config: project.configs.first!)
                try expect(buildSettings["SETTING1"] as? String) == "VALUE1"
                try expect(buildSettings["SETTING2"] as? String) == "VALUE2"
            }
        }
    }

    func testAggregateTargets() {
        describe {

            let aggregateTarget = AggregateTarget(name: "AggregateTarget", targets: ["MyApp", "MyFramework"])
            let project = Project(basePath: "", name: "test", targets: targets, aggregateTargets: [aggregateTarget])

            $0.it("generates aggregate targets") {
                let pbxProject = try project.generatePbxProj()
                let aggregateTargets = pbxProject.objects.aggregateTargets.referenceValues
                try expect(aggregateTargets.count) == 1
                guard let pbxAggregateTarget = aggregateTargets.first else {
                    throw failure("Couldn't find AggregateTarget")
                }

                try expect(pbxAggregateTarget.name) == "AggregateTarget"
                try expect(pbxAggregateTarget.dependencies.count) == 2

                let targetDependencies = pbxProject.objects.targetDependencies.referenceValues
                try expect(targetDependencies.count) == 4
            }
        }
    }

    func testTargets() {
        describe {

            let project = Project(basePath: "", name: "test", targets: targets)

            $0.it("generates targets") {
                let pbxProject = try project.generatePbxProj()
                let nativeTargets = pbxProject.objects.nativeTargets.referenceValues
                try expect(nativeTargets.count) == 3
                try expect(nativeTargets.contains { $0.name == app.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == framework.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == uiTest.name }).beTrue()
            }

            $0.it("generates target attributes") {
                var appTargetWithAttributes = app
                appTargetWithAttributes.settings.buildSettings["DEVELOPMENT_TEAM"] = "123"
                appTargetWithAttributes.attributes = ["ProvisioningStyle": "Automatic"]

                var testTargetWithAttributes = uiTest
                testTargetWithAttributes.settings.buildSettings["CODE_SIGN_STYLE"] = "Manual"
                let project = Project(basePath: "", name: "test", targets: [appTargetWithAttributes, framework, testTargetWithAttributes])
                let pbxProject = try project.generatePbxProj()

                guard let targetAttributes = pbxProject.objects.projects.referenceValues.first?.attributes["TargetAttributes"] as? [String: [String: Any]] else {
                    throw failure("Couldn't find Project TargetAttributes")
                }

                guard let appTarget = pbxProject.objects.targets(named: app.name).first else {
                    throw failure("Couldn't find App Target")
                }

                guard let uiTestTarget = pbxProject.objects.targets(named: uiTest.name).first else {
                    throw failure("Couldn't find UITest Target")
                }

                try expect(targetAttributes[uiTestTarget.reference]?["TestTargetID"] as? String) == appTarget.reference
                try expect(targetAttributes[uiTestTarget.reference]?["ProvisioningStyle"] as? String) == "Manual"
                try expect(targetAttributes[appTarget.reference]?["ProvisioningStyle"] as? String) == "Automatic"
                try expect(targetAttributes[appTarget.reference]?["DevelopmentTeam"] as? String) == "123"
            }

            $0.it("generates platform version") {
                let target = Target(name: "Target", type: .application, platform: .watchOS, deploymentTarget: "2.0")
                let project = Project(basePath: "", name: "", targets: [target], options: .init(deploymentTarget: DeploymentTarget(iOS: "10.0", watchOS: "3.0")))

                let pbxProject = try project.generatePbxProj()

                guard let projectConfigListReference = pbxProject.objects.projects.values.first?.buildConfigurationList,
                    let projectConfigReference = pbxProject.objects.configurationLists[projectConfigListReference]?.buildConfigurations.first,
                    let projectConfig = pbxProject.objects.buildConfigurations[projectConfigReference]
                else {
                    throw failure("Couldn't find Project config")
                }

                guard let targetConfigListReference = pbxProject.objects.nativeTargets.referenceValues.first?.buildConfigurationList,
                    let targetConfigReference = pbxProject.objects.configurationLists[targetConfigListReference]?.buildConfigurations.first,
                    let targetConfig = pbxProject.objects.buildConfigurations[targetConfigReference]
                else {
                    throw failure("Couldn't find Target config")
                }

                try expect(projectConfig.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"] as? String) == "10.0"
                try expect(projectConfig.buildSettings["WATCHOS_DEPLOYMENT_TARGET"] as? String) == "3.0"
                try expect(projectConfig.buildSettings["TVOS_DEPLOYMENT_TARGET"]).beNil()

                try expect(targetConfig.buildSettings["IPHONEOS_DEPLOYMENT_TARGET"]).beNil()
                try expect(targetConfig.buildSettings["WATCHOS_DEPLOYMENT_TARGET"] as? String) == "2.0"
                try expect(targetConfig.buildSettings["TVOS_DEPLOYMENT_TARGET"]).beNil()
            }

            $0.it("generates dependencies") {
                let pbxProject = try project.generatePbxProj()

                let nativeTargets = pbxProject.objects.nativeTargets.objectReferences
                let dependencies = pbxProject.objects.targetDependencies.objectReferences
                try expect(dependencies.count) == 2
                try expect(dependencies[0].object.target) == nativeTargets.first { $0.object.name == framework.name }!.reference
                try expect(dependencies[1].object.target) == nativeTargets.first { $0.object.name == app.name }!.reference
            }

            $0.it("generates targets with correct transitive embeds") {
                // App # Embeds it's frameworks, so shouldn't embed in tests
                //   dependencies:
                //     - framework: FrameworkA.framework
                //     - framework: FrameworkB.framework
                //       embed: false
                // iOSFrameworkZ:
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

                var expectedResourceFiles: [String: Set<String>] = [:]
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

                let staticLibrary = Target(
                    name: "StaticLibrary",
                    type: .staticLibrary,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .target, reference: iosFrameworkZ.name),
                        Dependency(type: .framework, reference: "FrameworkZ.framework"),
                        Dependency(type: .carthage, reference: "CarthageZ"),
                    ]
                )
                expectedResourceFiles[staticLibrary.name] = Set()
                expectedLinkedFiles[staticLibrary.name] = Set([])
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
                        Dependency(type: .carthage, reference: "CarthageA"),
                        // Statically linked, so don't embed into test
                        Dependency(type: .target, reference: staticLibrary.name),
                        Dependency(type: .carthage, reference: "CarthageB", embed: false),
                    ]
                )
                expectedResourceFiles[iosFrameworkA.name] = Set()
                expectedLinkedFiles[iosFrameworkA.name] = Set([
                    "FrameworkC.framework",
                    iosFrameworkZ.filename,
                    "FrameworkZ.framework",
                    "CarthageZ.framework",
                    "CarthageA.framework",
                    "CarthageB.framework",
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
                        Dependency(type: .carthage, reference: "CarthageC", embed: true),
                        // Statically linked, so don't embed into test
                        Dependency(type: .framework, reference: "FrameworkF.framework", embed: false),
                    ]
                )
                expectedResourceFiles[iosFrameworkB.name] = Set()
                expectedLinkedFiles[iosFrameworkB.name] = Set([
                    iosFrameworkA.filename,
                    iosFrameworkZ.filename,
                    "FrameworkZ.framework",
                    "CarthageZ.framework",
                    "FrameworkC.framework",
                    "FrameworkD.framework",
                    "FrameworkE.framework",
                    "FrameworkF.framework",
                    "CarthageA.framework",
                    "CarthageC.framework",
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
                        Dependency(type: .carthage, reference: "CarthageD"),
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
                    "FrameworkZ.framework",
                    "CarthageZ.framework",
                    "FrameworkC.framework",
                    iosFrameworkB.filename,
                    "FrameworkD.framework",
                    "CarthageA.framework",
                    "CarthageD.framework",
                ])
                expectedEmbeddedFrameworks[appTest.name] = Set([
                    iosFrameworkA.filename,
                    iosFrameworkZ.filename,
                    "FrameworkZ.framework",
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

                let targets = [app, iosFrameworkZ, staticLibrary, resourceBundle, iosFrameworkA, iosFrameworkB, appTest, appTestWithoutTransitive]

                let project = Project(
                    basePath: "",
                    name: "test",
                    targets: targets,
                    options: SpecOptions(transitivelyLinkDependencies: true)
                )
                let pbxProject = try project.generatePbxProj()

                for target in targets {
                    guard let nativeTarget = pbxProject.objects.nativeTargets.referenceValues.first(where: { $0.name == target.name }) else {
                        throw failure("PBXNativeTarget for \(target) not found")
                    }
                    let buildPhases = nativeTarget.buildPhases
                    let resourcesPhases = pbxProject.objects.resourcesBuildPhases.objectReferences.filter { buildPhases.contains($0.reference) }
                    let frameworkPhases = pbxProject.objects.frameworksBuildPhases.objectReferences.filter { buildPhases.contains($0.reference) }
                    let copyFilesPhases = pbxProject.objects.copyFilesBuildPhases.objectReferences.filter { buildPhases.contains($0.reference) }

                    // ensure only the right resources are copies, no more, no less
                    let expectedResourceFiles = expectedResourceFiles[target.name]!
                    try expect(resourcesPhases.count) == (expectedResourceFiles.isEmpty ? 0 : 1)
                    if !expectedResourceFiles.isEmpty {
                        let resourceFiles = resourcesPhases[0].object.files
                            .compactMap { pbxProject.objects.buildFiles[$0]?.fileRef.flatMap { pbxProject.objects.fileReferences[$0]?.nameOrPath } }
                        try expect(Set(resourceFiles)) == expectedResourceFiles
                    }

                    // ensure only the right things are linked, no more, no less
                    let expectedLinkedFiles = expectedLinkedFiles[target.name]!
                    try expect(frameworkPhases.count) == (expectedLinkedFiles.isEmpty ? 0 : 1)
                    if !expectedLinkedFiles.isEmpty {
                        let linkFrameworks = frameworkPhases[0].object.files
                            .compactMap { pbxProject.objects.buildFiles[$0]?.fileRef.flatMap { pbxProject.objects.fileReferences[$0]?.nameOrPath } }
                        try expect(Set(linkFrameworks)) == expectedLinkedFiles
                    }

                    // ensure only the right things are embedded, no more, no less
                    let expectedEmbeddedFrameworks = expectedEmbeddedFrameworks[target.name]!
                    try expect(copyFilesPhases.count) == (expectedEmbeddedFrameworks.isEmpty ? 0 : 1)
                    if !expectedEmbeddedFrameworks.isEmpty {
                        let copyFiles = copyFilesPhases[0].object.files
                            .compactMap { pbxProject.objects.buildFiles[$0]?.fileRef.flatMap { pbxProject.objects.fileReferences[$0]?.nameOrPath } }
                        try expect(Set(copyFiles)) == expectedEmbeddedFrameworks
                    }
                }
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
                    guard let nativeTarget = pbxProj.objects.targets(named: target.name).first?.object,
                        let buildConfigList = nativeTarget.buildConfigurationList,
                        let buildConfigs = pbxProj.objects.configurationLists.getReference(buildConfigList),
                        let buildConfigReference = buildConfigs.buildConfigurations.first,
                        let buildConfig = pbxProj.objects.buildConfigurations.getReference(buildConfigReference) else {
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
            
            $0.it("copies Swfit Objective-C Interface Header") {
                let swiftStaticLibraryWithHeader = Target(
                    name: "swiftStaticLibraryWithHeader",
                    type: .staticLibrary,
                    platform: .iOS,
                    sources: [TargetSource(path: "StaticLibrary_Swift/StaticLibrary.swift")],
                    dependencies: []
                )
                let swiftStaticLibraryWithoutHeader = Target(
                    name: "swiftStaticLibraryWithoutHeader",
                    type: .staticLibrary,
                    platform: .iOS,
                    settings: Settings(buildSettings: ["SWIFT_OBJC_INTERFACE_HEADER_NAME": ""]),
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
                
                let targets = [swiftStaticLibraryWithHeader, swiftStaticLibraryWithoutHeader, objCStaticLibrary]
                
                let project = Project(
                    basePath: fixturePath + "TestProject",
                    name: "test",
                    targets: targets,
                    options: SpecOptions()
                )
                
                let pbxProject = try project.generatePbxProj()
                
                func scriptBuildPhases(target: Target) throws -> [PBXShellScriptBuildPhase] {
                    guard let nativeTarget = pbxProject.objects.nativeTargets.referenceValues.first(where: { $0.name == target.name }) else {
                        throw failure("PBXNativeTarget for \(target) not found")
                    }
                    let buildPhases = nativeTarget.buildPhases
                    let scriptPhases = pbxProject.objects.shellScriptBuildPhases.objectReferences.filter({ buildPhases.contains($0.reference) }).map { $0.object }
                    return scriptPhases
                }
                
                let expectedScriptPhase = PBXShellScriptBuildPhase(
                    files: [],
                    name: "Copy Swift Objective-C Interface Header",
                    inputPaths: ["$(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                    outputPaths: ["$(BUILT_PRODUCTS_DIR)/include/$(PRODUCT_MODULE_NAME)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"],
                    shellPath: "/bin/sh",
                    shellScript: "ditto \"${SCRIPT_INPUT_FILE_0}\" \"${SCRIPT_OUTPUT_FILE_0}\"\n"
                )
                
                try expect(scriptBuildPhases(target: swiftStaticLibraryWithHeader)) == [expectedScriptPhase]
                try expect(scriptBuildPhases(target: swiftStaticLibraryWithoutHeader)) == []
                try expect(scriptBuildPhases(target: objCStaticLibrary)) == []
            }

            $0.it("generates run scripts") {
                var scriptSpec = project
                scriptSpec.targets[0].prebuildScripts = [BuildScript(script: .script("script1"))]
                scriptSpec.targets[0].postbuildScripts = [BuildScript(script: .script("script2"))]
                let pbxProject = try scriptSpec.generatePbxProj()

                guard let nativeTarget = pbxProject.objects.nativeTargets.referenceValues
                    .first(where: { $0.buildPhases.count >= 2 }) else {
                    throw failure("Target with build phases not found")
                }
                let buildPhases = nativeTarget.buildPhases

                let scripts = pbxProject.objects.shellScriptBuildPhases.objectReferences
                let script1 = scripts[0]
                let script2 = scripts[1]
                try expect(scripts.count) == 2
                try expect(buildPhases.first) == script1.reference
                try expect(buildPhases.last) == script2.reference

                try expect(script1.object.shellScript) == "script1"
                try expect(script2.object.shellScript) == "script2"
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
                    basePath: "",
                    name: "test",
                    targets: [target1, target2]
                )

                _ = try project.generatePbxProj()
            }

            $0.it("generates run scripts") {
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

                let buildRules = pbxProject.objects.buildRules.referenceValues
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
        }
    }

    func testSchemes() {
        describe {

            let buildTarget = Scheme.BuildTarget(target: app.name)
            $0.it("generates scheme") {
                let preAction = Scheme.ExecutionAction(name: "Script", script: "echo Starting", settingsTarget: app.name)
                let scheme = Scheme(
                    name: "MyScheme",
                    build: Scheme.Build(targets: [buildTarget], preActions: [preAction])
                )
                let project = Project(
                    basePath: "",
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()
                guard let target = xcodeProject.pbxproj.objects.nativeTargets.objectReferences
                    .first(where: { $0.object.name == app.name }) else {
                    throw failure("Target not found")
                }
                guard let xcscheme = xcodeProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }
                try expect(scheme.name) == "MyScheme"
                try expect(xcscheme.buildAction?.buildImplicitDependencies) == true
                try expect(xcscheme.buildAction?.parallelizeBuild) == true
                try expect(xcscheme.buildAction?.preActions.first?.title) == "Script"
                try expect(xcscheme.buildAction?.preActions.first?.scriptText) == "echo Starting"
                try expect(xcscheme.buildAction?.preActions.first?.environmentBuildable?.buildableName) == "MyApp.app"
                try expect(xcscheme.buildAction?.preActions.first?.environmentBuildable?.blueprintName) == "MyApp"
                guard let buildActionEntry = xcscheme.buildAction?.buildActionEntries.first else {
                    throw failure("Build Action entry not found")
                }
                try expect(buildActionEntry.buildFor) == BuildType.all

                let buildableReferences: [XCScheme.BuildableReference] = [
                    buildActionEntry.buildableReference,
                    xcscheme.launchAction?.buildableProductRunnable?.buildableReference,
                    xcscheme.profileAction?.buildableProductRunnable?.buildableReference,
                    xcscheme.testAction?.macroExpansion,
                ].compactMap { $0 }

                for buildableReference in buildableReferences {
                    try expect(buildableReference.blueprintIdentifier) == target.reference
                    try expect(buildableReference.blueprintName) == target.object.name
                    try expect(buildableReference.buildableName) == "\(target.object.name).\(target.object.productType!.fileExtension!)"
                }

                try expect(xcscheme.launchAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Release"
            }

            $0.it("sets environment variables for a scheme") {
                let runVariables: [XCScheme.EnvironmentVariable] = [
                    XCScheme.EnvironmentVariable(variable: "RUN_ENV", value: "ENABLED", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "OTHER_RUN_ENV", value: "DISABLED", enabled: false),
                ]

                let scheme = Scheme(
                    name: "EnvironmentVariablesScheme",
                    build: Scheme.Build(targets: [buildTarget]),
                    run: Scheme.Run(config: "Debug", environmentVariables: runVariables),
                    test: Scheme.Test(config: "Debug"),
                    profile: Scheme.Profile(config: "Debug")
                )
                let project = Project(
                    basePath: "",
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                guard let xcscheme = xcodeProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }

                try expect(
                    xcodeProject.pbxproj.objects.nativeTargets.objectReferences
                        .contains(where: { $0.object.name == app.name })
                ).beTrue()
                try expect(xcscheme.launchAction?.environmentVariables) == runVariables
                try expect(xcscheme.testAction?.environmentVariables).to.beNil()
                try expect(xcscheme.profileAction?.environmentVariables).to.beNil()
            }

            $0.it("generates target schemes from config variant") {
                let configVariants = ["Test", "Production"]
                var target = app
                target.scheme = TargetScheme(configVariants: configVariants)
                let configs: [Config] = [
                    Config(name: "Test Debug", type: .debug),
                    Config(name: "Production Debug", type: .debug),
                    Config(name: "Test Release", type: .release),
                    Config(name: "Production Release", type: .release),
                ]

                let project = Project(basePath: "", name: "test", configs: configs, targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 2

                guard let nativeTarget = xcodeProject.pbxproj.objects.nativeTargets.objectReferences
                    .first(where: { $0.object.name == app.name }) else {
                    throw failure("Target not found")
                }
                guard let xcscheme = xcodeProject.sharedData?.schemes
                    .first(where: { $0.name == "\(target.name) Test" }) else {
                    throw failure("Scheme not found")
                }
                guard let buildActionEntry = xcscheme.buildAction?.buildActionEntries.first else {
                    throw failure("Build Action entry not found")
                }
                try expect(buildActionEntry.buildableReference.blueprintIdentifier) == nativeTarget.reference

                try expect(xcscheme.launchAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Test Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Test Release"
            }

            $0.it("generates environment variables for target schemes") {
                let variables: [XCScheme.EnvironmentVariable] = [XCScheme.EnvironmentVariable(variable: "env", value: "var", enabled: false)]
                var target = app
                target.scheme = TargetScheme(environmentVariables: variables)

                let project = Project(basePath: "", name: "test", targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 1

                guard let xcscheme = xcodeProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }

                try expect(xcscheme.launchAction?.environmentVariables) == variables
                try expect(xcscheme.testAction?.environmentVariables) == variables
                try expect(xcscheme.profileAction?.environmentVariables) == variables
            }

            $0.it("generates pre and post actions for target schemes") {
                var target = app
                target.scheme = TargetScheme(
                    preActions: [.init(name: "Run", script: "do")],
                    postActions: [.init(name: "Run2", script: "post", settingsTarget: "MyApp")]
                )

                let project = Project(basePath: "", name: "test", targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 1

                guard let xcscheme = xcodeProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }

                try expect(xcscheme.launchAction?.preActions.count) == 1
                try expect(xcscheme.launchAction?.preActions.first?.title) == "Run"
                try expect(xcscheme.launchAction?.preActions.first?.scriptText) == "do"

                try expect(xcscheme.testAction?.postActions.count) == 1
                try expect(xcscheme.testAction?.postActions.first?.title) == "Run2"
                try expect(xcscheme.testAction?.postActions.first?.scriptText) == "post"
                try expect(xcscheme.testAction?.postActions.first?.environmentBuildable?.blueprintName) == "MyApp"
            }
        }
    }
}
