import Spectre
import XcodeGenKit
import xcproj
import PathKit
import ProjectSpec
import Yams

func projectGeneratorTests() {

    func getProject(_ spec: ProjectSpec) throws -> XcodeProj {
        let generator = ProjectGenerator(spec: spec)
        return try generator.generateProject()
    }

    func getPbxProj(_ spec: ProjectSpec) throws -> PBXProj {
        let project = try getProject(spec).pbxproj
        try project.validate()
        return project
    }

    describe("Project Generator") {

        let application = Target(name: "MyApp", type: .application, platform: .iOS,
                                 settings: Settings(buildSettings: ["SETTING_1": "VALUE"]),
                                 dependencies: [Dependency(type: .target, reference: "MyFramework")])

        let framework = Target(name: "MyFramework", type: .framework, platform: .iOS,
                               settings: Settings(buildSettings: ["SETTING_2": "VALUE"]))

        let targets = [application, framework]

        $0.describe("Options") {

            $0.it("generates bundle id") {
                let options = ProjectSpec.Options(bundleIdPrefix: "com.test")
                let spec = ProjectSpec(basePath: "", name: "test", targets: [framework], options: options)
                let project = try getProject(spec)
                guard let target = project.pbxproj.objects.nativeTargets.first?.value,
                    let buildConfigList = target.buildConfigurationList,
                    let buildConfigs = project.pbxproj.objects.configurationLists.getReference(buildConfigList),
                    let buildConfigReference = buildConfigs.buildConfigurations.first,
                    let buildConfig = project.pbxproj.objects.buildConfigurations.getReference(buildConfigReference) else {
                    throw failure("Build Config not found")
                }
                try expect(buildConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String) == "com.test.MyFramework"
            }

            $0.it("clears setting presets") {
                let options = ProjectSpec.Options(settingPresets: .none)
                let spec = ProjectSpec(basePath: "", name: "test", targets: [framework], options: options)
                let project = try getProject(spec)
                let allSettings = project.pbxproj.objects.buildConfigurations.referenceValues.reduce([:]) { $0.merged($1.buildSettings) }.keys.sorted()
                try expect(allSettings) == ["SETTING_2"]
            }

            $0.it("generates development language") {
                let options = ProjectSpec.Options(developmentLanguage: "de")
                let spec = ProjectSpec(basePath: "", name: "test", options: options)
                let project = try getProject(spec)
                guard let pbxProject = project.pbxproj.objects.projects.first?.value else {
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
        }

        $0.describe("Config") {

            $0.it("generates config defaults") {
                let spec = ProjectSpec(basePath: "", name: "test")
                let project = try getProject(spec)
                let configs = project.pbxproj.objects.buildConfigurations.referenceValues
                try expect(configs.count) == 2
                try expect(configs).contains(name: "Debug")
                try expect(configs).contains(name: "Release")
            }

            $0.it("generates configs") {
                let spec = ProjectSpec(basePath: "", name: "test", configs: [Config(name: "config1"), Config(name: "config2")])
                let project = try getProject(spec)
                let configs = project.pbxproj.objects.buildConfigurations.referenceValues
                try expect(configs.count) == 2
                try expect(configs).contains(name: "config1")
                try expect(configs).contains(name: "config2")
            }

            $0.it("clears config settings when missing type") {
                let spec = ProjectSpec(basePath: "", name: "test", configs: [Config(name: "config")])
                let project = try getProject(spec)
                guard let config = project.pbxproj.objects.buildConfigurations.first?.value else {
                    throw failure("configuration not found")
                }
                try expect(config.buildSettings.isEmpty).to.beTrue()
            }

            $0.it("merges settings") {
                let spec = try ProjectSpec(path: fixturePath + "settings_test.yml")
                guard let config = spec.getConfig("config1") else { throw failure("Couldn't find config1") }
                let debugProjectSettings = spec.getProjectBuildSettings(config: config)

                guard let target = spec.getTarget("Target") else { throw failure("Couldn't find Target") }
                let targetDebugSettings = spec.getTargetBuildSettings(target: target, config: config)

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
                let spec = ProjectSpec(basePath: "", name: "test", configs: [
                    Config(name: "Staging Debug", type: .debug),
                    Config(name: "Staging Release", type: .release),
                ],
                settings: Settings(configSettings: ["staging": ["SETTING1": "VALUE1"], "debug": ["SETTING2": "VALUE2"]]))

                var buildSettings = spec.getProjectBuildSettings(config: spec.configs.first!)
                try expect(buildSettings["SETTING1"] as? String) == "VALUE1"
                try expect(buildSettings["SETTING2"] as? String) == "VALUE2"
            }
        }

        $0.describe("Targets") {

            let spec = ProjectSpec(basePath: "", name: "test", targets: targets)

            $0.it("generates targets") {
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.objects.nativeTargets.referenceValues
                try expect(nativeTargets.count) == 2
                try expect(nativeTargets.contains { $0.name == application.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == framework.name }).beTrue()
            }

            $0.it("generates platform version") {
                let target = Target(name: "Target", type: .application, platform: .watchOS, deploymentTarget: "2.0")
                let spec = ProjectSpec(basePath: "", name: "", targets: [target], options: .init(deploymentTargets: DeploymentTargets(iOS: "10.0", watchOS: "3.0")))

                let pbxProject = try getPbxProj(spec)

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
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.objects.nativeTargets.referenceValues
                let dependencies = pbxProject.objects.targetDependencies.referenceValues
                try expect(dependencies.count) == 1
                try expect(dependencies.first!.target) == nativeTargets.first { $0.name == framework.name }!.reference
            }

            $0.it("generates run scripts") {
                var scriptSpec = spec
                scriptSpec.targets[0].prebuildScripts = [BuildScript(script: .script("script1"))]
                scriptSpec.targets[0].postbuildScripts = [BuildScript(script: .script("script2"))]
                let pbxProject = try getPbxProj(scriptSpec)

                guard let nativeTarget = pbxProject.objects.nativeTargets.referenceValues.first(where: { !$0.buildPhases.isEmpty }) else {
                    throw failure("Target with build phases not found")
                }
                let buildPhases = nativeTarget.buildPhases

                let scripts = pbxProject.objects.shellScriptBuildPhases.referenceValues
                let script1 = scripts[0]
                let script2 = scripts[1]
                try expect(scripts.count) == 2
                try expect(buildPhases.first) == script1.reference
                try expect(buildPhases.last) == script2.reference

                try expect(script1.shellScript) == "script1"
                try expect(script2.shellScript) == "script2"
            }

            $0.it("generates targets with cylical dependencies") {
                let target1 = Target(name: "target1", type: .framework, platform: .iOS, dependencies: [Dependency(type: .target, reference: "target2")])
                let target2 = Target(name: "target2", type: .framework, platform: .iOS, dependencies: [Dependency(type: .target, reference: "target1")])
                let spec = ProjectSpec(basePath: "", name: "test", targets: [target1, target2])

                _ = try getPbxProj(spec)
            }
        }

        $0.describe("Schemes") {

            let buildTarget = Scheme.BuildTarget(target: application.name)
            $0.it("generates scheme") {
                let scheme = Scheme(name: "MyScheme", build: Scheme.Build(targets: [buildTarget]))
                let spec = ProjectSpec(basePath: "", name: "test", targets: [application, framework], schemes: [scheme])
                let project = try getProject(spec)
                guard let target = project.pbxproj.objects.nativeTargets.referenceValues.first(where: { $0.name == application.name }) else { throw failure("Target not found") }
                guard let xcscheme = project.sharedData?.schemes.first else { throw failure("Scheme not found") }
                try expect(scheme.name) == "MyScheme"
                guard let buildActionEntry = xcscheme.buildAction?.buildActionEntries.first else { throw failure("Build Action entry not found") }
                try expect(buildActionEntry.buildFor) == BuildType.all

                let buildableReferences: [XCScheme.BuildableReference] = [
                    buildActionEntry.buildableReference,
                    xcscheme.launchAction?.buildableProductRunnable.buildableReference,
                    xcscheme.profileAction?.buildableProductRunnable.buildableReference,
                    xcscheme.testAction?.macroExpansion,
                ].flatMap { $0 }

                for buildableReference in buildableReferences {
                    try expect(buildableReference.blueprintIdentifier) == target.reference
                    try expect(buildableReference.blueprintName) == scheme.name
                    try expect(buildableReference.buildableName) == "\(target.name).\(target.productType!.fileExtension!)"
                }

                try expect(xcscheme.launchAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Release"
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

                let spec = ProjectSpec(basePath: "", name: "test", configs: configs, targets: [target, framework])
                let project = try getProject(spec)

                try expect(project.sharedData?.schemes.count) == 2

                guard let nativeTarget = project.pbxproj.objects.nativeTargets.referenceValues.first(where: { $0.name == application.name }) else { throw failure("Target not found") }
                guard let xcscheme = project.sharedData?.schemes.first(where: { $0.name == "\(target.name) Test" }) else { throw failure("Scheme not found") }
                guard let buildActionEntry = xcscheme.buildAction?.buildActionEntries.first else { throw failure("Build Action entry not found") }
                try expect(buildActionEntry.buildableReference.blueprintIdentifier) == nativeTarget.reference

                try expect(xcscheme.launchAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Test Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Test Release"
            }
        }

        $0.describe("Reference Generator") {

            let referenceGenerator = ReferenceGenerator()
            $0.before {
                referenceGenerator.clear()
            }

            $0.it("generates prefixes") {
                let references = [
                    referenceGenerator.generate(PBXGroup.self, "a"),
                    referenceGenerator.generate(PBXFileReference.self, "a"),
                    referenceGenerator.generate(XCConfigurationList.self, "a"),
                ]
                try expect(references[0].hasPrefix("G")).to.beTrue()
                try expect(references[1].hasPrefix("FR")).to.beTrue()
                try expect(references[2].hasPrefix("CL")).to.beTrue()
            }

            $0.it("handles duplicates") {
                let first = referenceGenerator.generate(PBXGroup.self, "a")
                let second = referenceGenerator.generate(PBXGroup.self, "a")

                try expect(first) != second
                try expect(second.hasSuffix("-1")).to.beTrue()
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "A", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "A", "B", "b.swift"], buildPhase: .sources)
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target], fileGroups: ["Sources"])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "a", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "a", "a", "a.swift"], buildPhase: .sources)
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "a.swift"], names: ["NewSource", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["OtherSource", "b.swift"], names: ["OtherSource", "c.swift"], buildPhase: .sources)
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
                    //"**/*.ignored",

                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", excludes: excludes)])
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "A", "a.swift"])
                try project.expectFile(paths: ["Sources", "D", "d.h"])
                try project.expectFile(paths: ["Sources", "D", "d.m"])
                try project.expectFile(paths: ["Sources", "E", "e.jpg"])
                try project.expectFile(paths: ["Sources", "E", "e.m"])
                try project.expectFile(paths: ["Sources", "E", "e.h"])
                try project.expectFile(paths: ["Sources", "types", "a.swift"])
                try project.expectFile(paths: ["Sources", "numbers", "file1.a"])
                try project.expectFile(paths: ["Sources", "numbers", "file4.a"])
                try project.expectFileMissing(paths: ["Sources", "B", "b.swift"])
                try project.expectFileMissing(paths: ["Sources", "E", "F", "f.swift"])
                try project.expectFileMissing(paths: ["Sources", "G", "H", "h.swift"])
                try project.expectFileMissing(paths: ["Sources", "types", "a.h"])
                try project.expectFileMissing(paths: ["Sources", "types", "a.x"])
                try project.expectFileMissing(paths: ["Sources", "numbers", "file2.a"])
                try project.expectFileMissing(paths: ["Sources", "numbers", "file3.a"])
                try project.expectFileMissing(paths: ["Sources", "partial", "file_part"])
                try project.expectFileMissing(paths: ["Sources", "a.ignored"])
                try project.expectFileMissing(paths: ["Sources", "ignore.file"])

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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources/A/B", "b.swift"], names: ["B", "b.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources/A/B", "c.jpg"], names: ["B", "c.jpg"], buildPhase: .resources)
                try project.expectFile(paths: ["Sources/A", "Assets.xcassets"], names: ["A", "Assets.xcassets"], buildPhase: .resources)
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target1, target2])

                _ = try getPbxProj(spec)
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
                let options = ProjectSpec.Options(createIntermediateGroups: true)
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "A", "b.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "F", "G", "h.swift"], buildPhase: .sources)
                try project.expectFile(paths: [(outOfRootPath + "C/D").string, "e.swift"], names: ["D", "e.swift"], buildPhase: .sources)
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources/A"], names: ["A"], buildPhase: .resources)
                try project.expectFileMissing(paths: ["Sources", "A", "a.swift"])
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
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target])

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["A", "file.swift"], buildPhase: .resources)
                try project.expectFile(paths: ["A", "file.xcassets"], buildPhase: .resources)
                try project.expectFile(paths: ["A", "file.h"], buildPhase: .resources)
                try project.expectFile(paths: ["A", "Info.plist"], buildPhase: .none)
                try project.expectFile(paths: ["A", "file.xcconfig"], buildPhase: .resources)

                try project.expectFile(paths: ["B", "file.swift"], buildPhase: .none)
                try project.expectFile(paths: ["B", "file.xcassets"], buildPhase: .none)
                try project.expectFile(paths: ["B", "file.h"], buildPhase: .none)
                try project.expectFile(paths: ["B", "Info.plist"], buildPhase: .none)
                try project.expectFile(paths: ["B", "file.xcconfig"], buildPhase: .none)

                try project.expectFile(paths: ["C", "file.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.m"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.mm"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.cpp"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.c"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.S"], buildPhase: .sources)
                try project.expectFile(paths: ["C", "file.h"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.hh"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.hpp"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.ipp"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.tpp"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.hxx"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.def"], buildPhase: .headers)
                try project.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.entitlements"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.gpx"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.apns"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try project.expectFile(paths: ["C", "file.xcassets"], buildPhase: .resources)
                try project.expectFile(paths: ["C", "file.123"], buildPhase: .resources)
                try project.expectFile(paths: ["C", "Info.plist"], buildPhase: .none)
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
            let buildFile = objects.buildFiles.referenceValues.first(where: { $0.fileRef == fileReference.reference })
            let actualBuildPhase = buildFile.flatMap { buildFile in objects.buildPhases.referenceValues.first { $0.files.contains(buildFile.reference) } }?.buildPhase

            var error: String?
            if let buildPhase = buildPhase.buildPhase {
                if actualBuildPhase != buildPhase {
                    if let actualBuildPhase = actualBuildPhase {
                        error = "is in the \(actualBuildPhase.rawValue) build phase instead of the expected \(buildPhase.rawValue.quoted)"
                    } else {
                        error = "isn't in a build phase when it's expected to be in \(buildPhase.rawValue.quoted)"
                    }
                }
            } else if let actualBuildPhase = actualBuildPhase  {
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

    func getFileReference(paths: [String], names: [String]) -> PBXFileReference? {
        guard let project = objects.projects.first?.value else { return nil }
        guard let mainGroup = objects.groups.getReference(project.mainGroup) else { return nil }

        return getFileReference(group: mainGroup, paths: paths, names: names)
    }

    func getMainGroup() throws -> PBXGroup {
        guard let project = objects.projects.first?.value else {
            throw failure("Couldn't find project")
        }
        guard let mainGroup = objects.groups.getReference(project.mainGroup) else {
            throw failure("Couldn't find main group")
        }
        return mainGroup
    }

    private func getFileReference(group: PBXGroup, paths: [String], names: [String]) -> PBXFileReference? {

        guard !paths.isEmpty else { return nil }
        let path = paths.first!
        let name = names.first!
        let restOfPath = Array(paths.dropFirst())
        let restOfName = Array(names.dropFirst())
        if restOfPath.isEmpty {
            let fileReferences = group.children.flatMap { self.objects.fileReferences.getReference($0) }
            return fileReferences.first { $0.path == path && $0.nameOrPath == name }
        } else {
            let groups = group.children.flatMap { self.objects.groups.getReference($0) }
            guard let group = groups.first(where: { $0.path == path && $0.nameOrPath == name }) else { return nil }
            return getFileReference(group: group, paths: restOfPath, names: restOfName)
        }
    }
}
