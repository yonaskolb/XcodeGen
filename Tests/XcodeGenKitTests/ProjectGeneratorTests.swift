import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcproj
import Yams

func projectGeneratorTests() {

    func getProject(_ project: Project) throws -> XcodeProj {
        let generator = ProjectGenerator(project: project)
        return try generator.generateProject()
    }

    func getPbxProj(_ project: Project) throws -> PBXProj {
        let pbxProject = try getProject(project).pbxproj
        try pbxProject.validate()
        return pbxProject
    }

    describe("Project Generator") {

        let application = Target(
            name: "MyApp",
            type: .application,
            platform: .iOS,
            settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
            dependencies: [Dependency(type: .target, reference: "MyFramework")]
        )

        let framework = Target(
            name: "MyFramework",
            type: .framework,
            platform: .iOS,
            settings: Settings(buildSettings: ["SETTING_2": "VALUE"])
        )

        let uiTest = Target(
            name: "MyAppUITests",
            type: .uiTestBundle,
            platform: .iOS,
            settings: Settings(buildSettings: ["SETTING_3": "VALUE"]),
            dependencies: [Dependency(type: .target, reference: "MyApp")]
        )

        let targets = [application, framework, uiTest]

        $0.describe("Options") {

            $0.it("generates bundle id") {
                let options = Project.Options(bundleIdPrefix: "com.test")
                let project = Project(basePath: "", name: "test", targets: [framework], options: options)
                let xcodeProject = try getProject(project)
                guard let target = xcodeProject.pbxproj.objects.nativeTargets.first?.value,
                    let buildConfigList = target.buildConfigurationList,
                    let buildConfigs = xcodeProject.pbxproj.objects.configurationLists.getReference(buildConfigList),
                    let buildConfigReference = buildConfigs.buildConfigurations.first,
                    let buildConfig = xcodeProject.pbxproj.objects.buildConfigurations.getReference(buildConfigReference) else {
                    throw failure("Build Config not found")
                }
                try expect(buildConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String) == "com.test.MyFramework"
            }

            $0.it("clears setting presets") {
                let options = Project.Options(settingPresets: .none)
                let project = Project(basePath: "", name: "test", targets: [framework], options: options)
                let xcodeProject = try getProject(project)
                let allSettings = xcodeProject.pbxproj.objects.buildConfigurations.referenceValues.reduce([:]) { $0.merged($1.buildSettings) }.keys.sorted()
                try expect(allSettings) == ["SETTING_2"]
            }

            $0.it("generates development language") {
                let options = Project.Options(developmentLanguage: "de")
                let project = Project(basePath: "", name: "test", options: options)
                let xcodeProject = try getProject(project)
                guard let pbxProject = xcodeProject.pbxproj.objects.projects.first?.value else {
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
                let options = Project.Options(defaultConfig: "Bconfig")
                let project = Project(basePath: "", name: "test", configs: [Config(name: "Aconfig"), Config(name: "Bconfig")], targets: [framework], options: options)
                let xcodeProject = try getPbxProj(project)

                guard let projectConfigListReference = xcodeProject.objects.projects.values.first?.buildConfigurationList,
                    let defaultConfigurationName = xcodeProject.objects.configurationLists[projectConfigListReference]?.defaultConfigurationName
                else {
                    throw failure("Default configuration name not found")
                }

                try expect(defaultConfigurationName) == "Bconfig"
            }
        }

        $0.describe("Config") {

            $0.it("generates config defaults") {
                let project = Project(basePath: "", name: "test")
                let xcodeProject = try getProject(project)
                let configs = xcodeProject.pbxproj.objects.buildConfigurations.referenceValues
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
                let xcodeProject = try getProject(project)
                let configs = xcodeProject.pbxproj.objects.buildConfigurations.referenceValues
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
                let xcodeProject = try getProject(project)
                guard let config = xcodeProject.pbxproj.objects.buildConfigurations.first?.value else {
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

        $0.describe("Targets") {

            let project = Project(basePath: "", name: "test", targets: targets)

            $0.it("generates targets") {
                let pbxProject = try getPbxProj(project)
                let nativeTargets = pbxProject.objects.nativeTargets.referenceValues
                try expect(nativeTargets.count) == 3
                try expect(nativeTargets.contains { $0.name == application.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == framework.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == uiTest.name }).beTrue()
            }

            $0.it("generates target attributes") {

                let pbxProject = try getPbxProj(project)

                guard let targetAttributes = pbxProject.objects.projects.referenceValues.first?.attributes["TargetAttributes"] as? [String: [String: Any]] else {
                    throw failure("Couldn't find Project TargetAttributes")
                }

                guard let appTarget = pbxProject.objects.targets(named: application.name).first else {
                    throw failure("Couldn't find App Target")
                }

                guard let uiTestTarget = pbxProject.objects.targets(named: uiTest.name).first else {
                    throw failure("Couldn't find UITest Target")
                }

                try expect(targetAttributes[uiTestTarget.reference]?["TestTargetID"] as? String) == appTarget.reference
            }

            $0.it("generates platform version") {
                let target = Target(name: "Target", type: .application, platform: .watchOS, deploymentTarget: "2.0")
                let project = Project(basePath: "", name: "", targets: [target], options: .init(deploymentTarget: DeploymentTarget(iOS: "10.0", watchOS: "3.0")))

                let pbxProject = try getPbxProj(project)

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
                let pbxProject = try getPbxProj(project)

                let nativeTargets = pbxProject.objects.nativeTargets.objectReferences
                let dependencies = pbxProject.objects.targetDependencies.objectReferences
                try expect(dependencies.count) == 2
                try expect(dependencies[0].object.target) == nativeTargets.first { $0.object.name == framework.name }!.reference
                try expect(dependencies[1].object.target) == nativeTargets.first { $0.object.name == application.name }!.reference
            }

            $0.it("generates run scripts") {
                var scriptSpec = project
                scriptSpec.targets[0].prebuildScripts = [BuildScript(script: .script("script1"))]
                scriptSpec.targets[0].postbuildScripts = [BuildScript(script: .script("script2"))]
                let pbxProject = try getPbxProj(scriptSpec)

                guard let nativeTarget = pbxProject.objects.nativeTargets.referenceValues
                    .first(where: { !$0.buildPhases.isEmpty }) else {
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

                _ = try getPbxProj(project)
            }
        }

        $0.describe("Schemes") {

            let buildTarget = Scheme.BuildTarget(target: application.name)
            $0.it("generates scheme") {
                let preAction = Scheme.ExecutionAction(name: "Script", script: "echo Starting", settingsTarget: application.name)
                let scheme = Scheme(
                    name: "MyScheme",
                    build: Scheme.Build(targets: [buildTarget], preActions: [preAction])
                )
                let project = Project(
                    basePath: "",
                    name: "test",
                    targets: [application, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try getProject(project)
                guard let target = xcodeProject.pbxproj.objects.nativeTargets.objectReferences
                    .first(where: { $0.object.name == application.name }) else {
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
                ].flatMap { $0 }

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
                    targets: [application, framework],
                    schemes: [scheme]
                )
                let pbxProject = try getProject(project)

                guard let target = pbxProject.pbxproj.objects.nativeTargets.objectReferences
                    .first(where: { $0.object.name == application.name }) else {
                    throw failure("Target not found")
                }

                guard let xcscheme = pbxProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }

                try expect(xcscheme.launchAction?.environmentVariables) == runVariables
                try expect(xcscheme.testAction?.environmentVariables).to.beNil()
                try expect(xcscheme.profileAction?.environmentVariables).to.beNil()
            }

            $0.it("generates target schemes from config variant") {
                let configVariants = ["Test", "Production"]
                var target = application
                target.scheme = TargetScheme(configVariants: configVariants)
                let configs: [Config] = [
                    Config(name: "Test Debug", type: .debug),
                    Config(name: "Production Debug", type: .debug),
                    Config(name: "Test Release", type: .release),
                    Config(name: "Production Release", type: .release),
                ]

                let project = Project(basePath: "", name: "test", configs: configs, targets: [target, framework])
                let xcodeProject = try getProject(project)

                try expect(xcodeProject.sharedData?.schemes.count) == 2

                guard let nativeTarget = xcodeProject.pbxproj.objects.nativeTargets.objectReferences
                    .first(where: { $0.object.name == application.name }) else {
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
                var target = application
                target.scheme = TargetScheme(environmentVariables: variables)

                let project = Project(basePath: "", name: "test", targets: [target, framework])
                let xcodeProject = try getProject(project)

                try expect(xcodeProject.sharedData?.schemes.count) == 1

                guard let xcscheme = xcodeProject.sharedData?.schemes.first else {
                    throw failure("Scheme not found")
                }

                try expect(xcscheme.launchAction?.environmentVariables) == variables
                try expect(xcscheme.testAction?.environmentVariables) == variables
                try expect(xcscheme.profileAction?.environmentVariables) == variables
            }
        }

        $0.describe("Sources") {

            let directoryPath = Path("TestDirectory")
            let outOfRootPath = Path("OtherDirectory")

            func createDirectories(_ directories: String) throws {

                let yaml = try Yams.load(yaml: directories)!

                func getFiles(_ file: Any, path: Path) -> [Path] {
                    if let array = file as? [Any] {
                        return array.flatMap { getFiles($0, path: path) }
                    } else if let string = file as? String {
                        return [path + string]
                    } else if let dictionary = file as? [String: Any] {
                        var array: [Path] = []
                        for (key, value) in dictionary {
                            array += getFiles(value, path: path + key)
                        }
                        return array
                    } else {
                        return []
                    }
                }

                let files = getFiles(yaml, path: directoryPath).filter { $0.extension != nil }
                for file in files {
                    try file.parent().mkpath()
                    try file.write("")
                }
            }

            func removeDirectories() {
                try? directoryPath.delete()
                try? outOfRootPath.delete()
            }

            $0.before {
                removeDirectories()
            }

            $0.after {
                removeDirectories()
            }

            $0.it("generates source groups") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - B:
                      - b.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources", "A", "a.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources", "A", "B", "b.swift"], buildPhase: .sources)
            }

            $0.it("generates core data models") {
                let directories = """
                Sources:
                    model.xcdatamodeld:
                        - model.xcdatamodel
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                guard let fileReference = pbxProject.objects.fileReferences.first(where: { $0.value.nameOrPath == "model.xcdatamodel" }) else {
                    throw failure("Couldn't find model file reference")
                }
                guard let versionGroup = pbxProject.objects.versionGroups.values.first else {
                    throw failure("Couldn't find version group")
                }
                try expect(versionGroup.currentVersion) == fileReference.key
                try expect(versionGroup.children) == [fileReference.key]
                try expect(versionGroup.path) == "model.xcdatamodeld"
                try expect(fileReference.value.path) == "model.xcdatamodel"
            }

            $0.it("handles duplicate names") {
                let directories = """
                Sources:
                  - a.swift
                  - a:
                    - a.swift
                    - a:
                      - a.swift

                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(
                    basePath: directoryPath,
                    name: "Test",
                    targets: [target],
                    fileGroups: ["Sources"]
                )

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources", "a.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources", "a", "a.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources", "a", "a", "a.swift"], buildPhase: .sources)
            }

            $0.it("renames sources") {
                let directories = """
                Sources:
                    - a.swift
                OtherSource:
                    - b.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Sources", name: "NewSource"),
                    TargetSource(path: "OtherSource/b.swift", name: "c.swift"),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources", "a.swift"], names: ["NewSource", "a.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["OtherSource", "b.swift"], names: ["OtherSource", "c.swift"], buildPhase: .sources)
            }

            $0.it("excludes sources") {
                let directories = """
                Sources:
                  - A:
                    - a.swift
                    - B:
                      - b.swift
                      - b.ignored
                    - a.ignored
                  - B:
                    - b.swift
                  - D:
                    - d.h
                    - d.m
                  - E:
                    - e.jpg
                    - e.h
                    - e.m
                    - F:
                      - f.swift
                  - G:
                    - H:
                      - h.swift
                  - types:
                    - a.swift
                    - a.m
                    - a.h
                    - a.x
                  - numbers:
                    - file1.a
                    - file2.a
                    - file3.a
                    - file4.a
                  - partial:
                    - file_part
                  - ignore.file
                  - a.ignored

                """
                try createDirectories(directories)

                let excludes = [
                    "B",
                    "d.m",
                    "E/F/*.swift",
                    "G/H/",
                    "types/*.[hx]",
                    "numbers/file[2-3].a",
                    "partial/*_part",
                    "ignore.file",
                    "*.ignored",
                    // not supported
                    // "**/*.ignored",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", excludes: excludes)])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources", "A", "a.swift"])
                try pbxProject.expectFile(paths: ["Sources", "D", "d.h"])
                try pbxProject.expectFile(paths: ["Sources", "D", "d.m"])
                try pbxProject.expectFile(paths: ["Sources", "E", "e.jpg"])
                try pbxProject.expectFile(paths: ["Sources", "E", "e.m"])
                try pbxProject.expectFile(paths: ["Sources", "E", "e.h"])
                try pbxProject.expectFile(paths: ["Sources", "types", "a.swift"])
                try pbxProject.expectFile(paths: ["Sources", "numbers", "file1.a"])
                try pbxProject.expectFile(paths: ["Sources", "numbers", "file4.a"])
                try pbxProject.expectFileMissing(paths: ["Sources", "B", "b.swift"])
                try pbxProject.expectFileMissing(paths: ["Sources", "E", "F", "f.swift"])
                try pbxProject.expectFileMissing(paths: ["Sources", "G", "H", "h.swift"])
                try pbxProject.expectFileMissing(paths: ["Sources", "types", "a.h"])
                try pbxProject.expectFileMissing(paths: ["Sources", "types", "a.x"])
                try pbxProject.expectFileMissing(paths: ["Sources", "numbers", "file2.a"])
                try pbxProject.expectFileMissing(paths: ["Sources", "numbers", "file3.a"])
                try pbxProject.expectFileMissing(paths: ["Sources", "partial", "file_part"])
                try pbxProject.expectFileMissing(paths: ["Sources", "a.ignored"])
                try pbxProject.expectFileMissing(paths: ["Sources", "ignore.file"])
            }

            $0.it("generates file sources") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - Assets.xcassets
                    - B:
                      - b.swift
                      - c.jpg
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/a.swift",
                    "Sources/A/B/b.swift",
                    "Sources/A/Assets.xcassets",
                    "Sources/A/B/c.jpg",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources/A/B", "b.swift"], names: ["B", "b.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources/A/B", "c.jpg"], names: ["B", "c.jpg"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["Sources/A", "Assets.xcassets"], names: ["A", "Assets.xcassets"], buildPhase: .resources)
            }

            $0.it("generates shared sources") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - B:
                      - b.swift
                      - c.jpg
                """
                try createDirectories(directories)

                let target1 = Target(name: "Test1", type: .framework, platform: .iOS, sources: ["Sources"])
                let target2 = Target(name: "Test2", type: .framework, platform: .tvOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target1, target2])

                _ = try getPbxProj(project)
                // TODO: check there are build files for both targets
            }

            $0.it("generates intermediate groups") {

                let directories = """
                Sources:
                  A:
                    - b.swift
                  F:
                    - G:
                      - h.swift
                """
                try createDirectories(directories)
                let outOfSourceFile = outOfRootPath + "C/D/e.swift"
                try outOfSourceFile.parent().mkpath()
                try outOfSourceFile.write("")

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/b.swift",
                    "Sources/F/G/h.swift",
                    "../OtherDirectory/C/D/e.swift",
                ])
                let options = Project.Options(createIntermediateGroups: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources", "A", "b.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["Sources", "F", "G", "h.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: [(outOfRootPath + "C/D").string, "e.swift"], names: ["D", "e.swift"], buildPhase: .sources)
            }

            $0.it("generates folder references") {
                let directories = """
                Sources:
                  A:
                    - a.resource
                    - b.resource
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Sources/A", type: .folder),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources/A"], names: ["A"], buildPhase: .resources)
                try pbxProject.expectFileMissing(paths: ["Sources", "A", "a.swift"])
            }

            $0.it("adds files to correct build phase") {
                let directories = """
                  A:
                    - file.swift
                    - file.xcassets
                    - file.h
                    - Info.plist
                    - file.xcconfig
                  B:
                    - file.swift
                    - file.xcassets
                    - file.h
                    - Info.plist
                    - file.xcconfig
                  C:
                    - file.swift
                    - file.m
                    - file.mm
                    - file.cpp
                    - file.c
                    - file.S
                    - file.h
                    - file.hh
                    - file.hpp
                    - file.ipp
                    - file.tpp
                    - file.hxx
                    - file.def
                    - file.xcconfig
                    - file.entitlements
                    - file.gpx
                    - file.apns
                    - file.123
                    - file.xcassets
                    - Info.plist
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .framework, platform: .iOS, sources: [
                    TargetSource(path: "A", buildPhase: .resources),
                    TargetSource(path: "B", buildPhase: .none),
                    TargetSource(path: "C", buildPhase: nil),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["A", "file.swift"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["A", "file.xcassets"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["A", "file.h"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["A", "Info.plist"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["A", "file.xcconfig"], buildPhase: .resources)

                try pbxProject.expectFile(paths: ["B", "file.swift"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["B", "file.xcassets"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["B", "file.h"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["B", "Info.plist"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["B", "file.xcconfig"], buildPhase: .none)

                try pbxProject.expectFile(paths: ["C", "file.swift"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.m"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.mm"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.cpp"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.c"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.S"], buildPhase: .sources)
                try pbxProject.expectFile(paths: ["C", "file.h"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.hh"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.hpp"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.ipp"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.tpp"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.hxx"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.def"], buildPhase: .headers)
                try pbxProject.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.entitlements"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.gpx"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.apns"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProject.expectFile(paths: ["C", "file.xcassets"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["C", "file.123"], buildPhase: .resources)
                try pbxProject.expectFile(paths: ["C", "Info.plist"], buildPhase: .none)
            }

            $0.it("duplicate TargetSource is included once in sources build phase") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/a.swift",
                    "Sources/A/a.swift",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProject = try getPbxProj(project)
                try pbxProject.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)

                let sourcesBuildPhase = pbxProject.objects.buildPhases
                    .first(where: { $0.1.buildPhase == BuildPhase.sources })!
                    .value

                try expect(sourcesBuildPhase.files.count) == 1
            }
        }
    }
}

extension PBXProj {

    // validates that a PBXProj is correct
    // TODO: Use xclint?
    func validate() throws {
        let mainGroup = try getMainGroup()

        func validateGroup(_ group: PBXGroup) throws {
            let hasDuplicatedChildren = group.children.count != Set(group.children).count
            if hasDuplicatedChildren {
                throw failure("Group \"\(group.nameOrPath)\" has duplicated children:\n - \(group.children.sorted().joined(separator: "\n - "))")
            }
            for child in group.children {
                if let group = objects.groups.getReference(child) {
                    try validateGroup(group)
                }
            }
        }
        try validateGroup(mainGroup)
    }
}

extension PBXProj {

    /// expect a file within groups of the paths, using optional different names
    func expectFile(paths: [String], names: [String]? = nil, buildPhase: TargetSource.BuildPhase? = nil) throws {
        guard let fileReference = getFileReference(paths: paths, names: names ?? paths) else {
            var error = "Could not find file at path \(paths.joined(separator: "/").quoted)"
            if let names = names, names != paths {
                error += " and name \(names.joined(separator: "/").quoted)"
            }
            throw failure(error)
        }

        if let buildPhase = buildPhase {
            let buildFile = objects.buildFiles.objectReferences
                .first(where: { $0.object.fileRef == fileReference.reference })
            let actualBuildPhase = buildFile
                .flatMap { buildFile in objects.buildPhases.referenceValues.first { $0.files.contains(buildFile.reference) } }?.buildPhase

            var error: String?
            if let buildPhase = buildPhase.buildPhase {
                if actualBuildPhase != buildPhase {
                    if let actualBuildPhase = actualBuildPhase {
                        error = "is in the \(actualBuildPhase.rawValue) build phase instead of the expected \(buildPhase.rawValue.quoted)"
                    } else {
                        error = "isn't in a build phase when it's expected to be in \(buildPhase.rawValue.quoted)"
                    }
                }
            } else if let actualBuildPhase = actualBuildPhase {
                error = "is in the \(actualBuildPhase.rawValue.quoted) build phase when it's expected to not be in any"
            }
            if let error = error {
                throw failure("File \(paths.joined(separator: "/").quoted) \(error)")
            }
        }
    }

    /// expect a missing file within groups of the paths, using optional different names
    func expectFileMissing(paths: [String], names: [String]? = nil) throws {
        let names = names ?? paths
        if getFileReference(paths: paths, names: names) != nil {
            throw failure("Found unexpected file at path \(paths.joined(separator: "/").quoted) and name \(paths.joined(separator: "/").quoted)")
        }
    }

    func getFileReference(paths: [String], names: [String]) -> ObjectReference<PBXFileReference>? {
        guard let pbxProject = objects.projects.first?.value else { return nil }
        guard let mainGroup = objects.groups.getReference(pbxProject.mainGroup) else { return nil }

        return getFileReference(group: mainGroup, paths: paths, names: names)
    }

    func getMainGroup() throws -> PBXGroup {
        guard let pbxProject = objects.projects.first?.value else {
            throw failure("Couldn't find pbxProject")
        }
        guard let mainGroup = objects.groups.getReference(pbxProject.mainGroup) else {
            throw failure("Couldn't find main group")
        }
        return mainGroup
    }

    private func getFileReference(group: PBXGroup, paths: [String], names: [String]) -> ObjectReference<PBXFileReference>? {

        guard !paths.isEmpty else { return nil }
        let path = paths.first!
        let name = names.first!
        let restOfPath = Array(paths.dropFirst())
        let restOfName = Array(names.dropFirst())
        if restOfPath.isEmpty {
            let fileReferences: [ObjectReference<PBXFileReference>] = group.children.flatMap { reference in
                if let fileReference = self.objects.fileReferences.getReference(reference) {
                    return ObjectReference(reference: reference, object: fileReference)
                } else {
                    return nil
                }
            }
            return fileReferences.first { $0.object.path == path && $0.object.nameOrPath == name }
        } else {
            let groups = group.children.flatMap { self.objects.groups.getReference($0) }
            guard let group = groups.first(where: { $0.path == path && $0.nameOrPath == name }) else { return nil }
            return getFileReference(group: group, paths: restOfPath, names: restOfName)
        }
    }
}
