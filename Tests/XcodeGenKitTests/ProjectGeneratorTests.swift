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
        try spec.validate()
        return try getProject(spec).pbxproj
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
                guard let target = project.pbxproj.nativeTargets.first,
                    let buildConfigList = target.buildConfigurationList,
                    let buildConfigs = project.pbxproj.configurationLists.getReference(buildConfigList),
                    let buildConfigReference = buildConfigs.buildConfigurations.first,
                    let buildConfig = project.pbxproj.buildConfigurations.getReference(buildConfigReference) else {
                    throw failure("Build Config not found")
                }
                try expect(buildConfig.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String) == "com.test.MyFramework"
            }

            $0.it("clears setting presets") {
                let options = ProjectSpec.Options(settingPresets: .none)
                let spec = ProjectSpec(basePath: "", name: "test", targets: [framework], options: options)
                let project = try getProject(spec)
                let allSettings = project.pbxproj.buildConfigurations.reduce([:]) { $0.merged($1.buildSettings) }.keys.sorted()
                try expect(allSettings) == ["SETTING_2"]
            }
        }

        $0.describe("Config") {

            $0.it("generates config defaults") {
                let spec = ProjectSpec(basePath: "", name: "test")
                let project = try getProject(spec)
                let configs = project.pbxproj.buildConfigurations
                try expect(configs.count) == 2
                try expect(configs).contains(name: "Debug")
                try expect(configs).contains(name: "Release")
            }

            $0.it("generates configs") {
                let spec = ProjectSpec(basePath: "", name: "test", configs: [Config(name: "config1"), Config(name: "config2")])
                let project = try getProject(spec)
                let configs = project.pbxproj.buildConfigurations
                try expect(configs.count) == 2
                try expect(configs).contains(name: "config1")
                try expect(configs).contains(name: "config2")
            }

            $0.it("clears config settings when missing type") {
                let spec = ProjectSpec(basePath: "", name: "test", configs: [Config(name: "config")])
                let project = try getProject(spec)
                guard let config = project.pbxproj.buildConfigurations.first else {
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
                let nativeTargets = pbxProject.nativeTargets
                try expect(nativeTargets.count) == 2
                try expect(nativeTargets.contains { $0.name == application.name }).beTrue()
                try expect(nativeTargets.contains { $0.name == framework.name }).beTrue()
            }

            $0.it("generates dependencies") {
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.nativeTargets
                let dependencies = pbxProject.targetDependencies
                try expect(dependencies.count) == 1
                try expect(dependencies.first!.target) == nativeTargets.first { $0.name == framework.name }!.reference
            }

            $0.it("generates dependencies") {
                let pbxProject = try getPbxProj(spec)
                let nativeTargets = pbxProject.nativeTargets
                let dependencies = pbxProject.targetDependencies
                try expect(dependencies.count) == 1
                try expect(dependencies.first!.target) == nativeTargets.first { $0.name == framework.name }!.reference
            }

            $0.it("generates run scripts") {
                var scriptSpec = spec
                scriptSpec.targets[0].prebuildScripts = [BuildScript(script: .script("script1"))]
                scriptSpec.targets[0].postbuildScripts = [BuildScript(script: .script("script2"))]
                let pbxProject = try getPbxProj(scriptSpec)

                guard let buildPhases = pbxProject.nativeTargets.first?.buildPhases else { throw failure("Build phases not found") }

                let scripts = pbxProject.shellScriptBuildPhases
                let script1 = scripts[0]
                let script2 = scripts[1]
                try expect(scripts.count) == 2
                try expect(buildPhases.first) == script1.reference
                try expect(buildPhases.last) == script2.reference

                try expect(script1.shellScript) == "script1"
                try expect(script2.shellScript) == "script2"
            }
        }

        $0.describe("Schemes") {

            let buildTarget = Scheme.BuildTarget(target: application.name)
            $0.it("generates scheme") {
                let scheme = Scheme(name: "MyScheme", build: Scheme.Build(targets: [buildTarget]))
                let spec = ProjectSpec(basePath: "", name: "test", targets: [application, framework], schemes: [scheme])
                let project = try getProject(spec)
                guard let target = project.pbxproj.nativeTargets.first(where: { $0.name == application.name }) else { throw failure("Target not found") }
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

                guard let nativeTarget = project.pbxproj.nativeTargets.first(where: { $0.name == application.name }) else { throw failure("Target not found") }
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

        $0.describe("Sources") {

            let directoryPath = Path("TestDirectory")

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

            $0.it("generates source groups with excludes") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - B:
                      - b.swift
                  B:
                    - b.swift
                  C:
                    - c.swift
                    - c.m
                    - c.h
                  D:
                    - d.h
                    - d.m
                  E:
                    - e.jpg
                    - e.h
                    - e.m
                    - F:
                      - f.swift
                  G:
                    H:
                     - h.swift
                """
                try createDirectories(directories)

                let excludes = [
                    "B",
                    "C/*.h",
                    "d.m",
                    "E/F/*.swift",
                    "G/H/"
                ]

                target.sources = [Source(path: "Sources", excludes: excludes)]
                spec.targets = [target]

                let project = try getPbxProj(spec)
                try project.expectFile(paths: ["Sources", "A", "a.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "C", "c.swift"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "C", "c.m"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "D", "d.h"])
                try project.expectFile(paths: ["Sources", "D", "d.m"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "E", "e.jpg"], buildPhase: .resources)
                try project.expectFile(paths: ["Sources", "E", "e.m"], buildPhase: .sources)
                try project.expectFile(paths: ["Sources", "E", "e.h"])
                try project.expectFileMissing(paths: ["Sources/B", "b.swift"])
                try project.expectFileMissing(paths: ["Sources/C", "c.h"])
                try project.expectFileMissing(paths: ["Sources/E/F", "f.swift"])
                try project.expectFileMissing(paths: ["Sources/G/H", "h.swift"])
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

                var target1 = Target(name: "Test1", type: .framework, platform: .iOS, sources: ["Sources"])
                var target2 = Target(name: "Test2", type: .framework, platform: .tvOS, sources: ["Sources"])
                let spec = ProjectSpec(basePath: directoryPath, name: "Test", targets: [target1, target2])

                let proj = try getPbxProj(spec)

                guard let project = proj.projects.first,
                    let mainGroup = proj.groups.getReference(project.mainGroup) else {
                    throw failure("Couldn't find main group")
                }

                func validateGroup(_ group: PBXGroup) throws {
                    let hasDuplicatedChildren = group.children.count != Set(group.children).count
                    if hasDuplicatedChildren {
                        throw failure("Group \"\(group.nameOrPath ?? "")\" has duplicated children:\n - \(group.children.sorted().joined(separator: "\n - "))")
                    }
                    for child in group.children {
                        if let group = proj.groups.getReference(child) {
                            try validateGroup(group)
                        }
                    }
                }
                try validateGroup(mainGroup)
            }
        }
    }
}

extension PBXProj {

    /// expect a file within groups of the paths, using optional different names
    func expectFile(paths: [String], names: [String]? = nil, buildPhase: BuildPhase? = nil) throws {
        let names = names ?? paths
        guard let fileReference = getFileReference(paths: paths, names: names) else {
            var error = "Could not find file at path \(paths.joined(separator: "/").quoted)"
            if paths != names {
                error += " and name \(paths.joined(separator: "/").quoted)"
            }
            throw failure(error)
        }

        if let buildPhase = buildPhase {
            guard let buildFile = buildFiles.first(where: { $0.fileRef == fileReference.reference}),
            getBuildPhases(buildPhase).contains(where: { $0.files.contains(buildFile.reference)}) else {
                throw failure("File \(paths.joined(separator: "/").quoted) is not in a \(buildPhase.rawValue.quoted) build phase")
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
        guard let project = projects.first else { return nil }
        guard let mainGroup = groups.getReference(project.mainGroup) else { return nil }

        return getFileReference(group: mainGroup, paths: paths, names: names)
    }

    private func getFileReference(group: PBXGroup, paths: [String], names: [String]) -> PBXFileReference? {

        guard !paths.isEmpty else { return nil }
        let path = paths.first!
        let name = names.first!
        let restOfPath = Array(paths.dropFirst())
        let restOfName = Array(names.dropFirst())
        if restOfPath.isEmpty {
            let fileReferences = group.children.flatMap { self.fileReferences.getReference($0) }
            return fileReferences.first { $0.path == path && $0.nameOrPath == name }
        } else {
            let groups = group.children.flatMap { self.groups.getReference($0) }
            guard let group = groups.first(where: { $0.path == path && $0.nameOrPath == name }) else { return nil }
            return getFileReference(group: group, paths: restOfPath, names: restOfName)
        }
    }

    func getBuildPhases(_ buildPhase: BuildPhase) -> [PBXBuildPhase] {
        switch buildPhase {
        case .copyFiles: return copyFilesBuildPhases
        case .sources: return sourcesBuildPhases
        case .frameworks: return frameworksBuildPhases
        case .resources: return resourcesBuildPhases
        case .runScript: return shellScriptBuildPhases
        case .headers: return headersBuildPhases
        }
    }
}

extension PBXFileReference {
    var nameOrPath: String? {
        return name ?? path
    }
}

extension PBXGroup {
    var nameOrPath: String? {
        return name ?? path
    }
}
