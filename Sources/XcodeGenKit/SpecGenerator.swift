import Foundation
import ProjectSpec
import XcodeProj
import PathKit

public enum SpecGenerationError: Error, CustomStringConvertible {
    case rootObjectNotFound

    public var description: String {
        switch self {
        case .rootObjectNotFound:
            return "Project does not contain root project"
        }
    }
}

/**
 Generate project spec from XcodeProj

 Basically, it is a process of mapping the types defined in XcodeProj to the types defined in XcodeGen.
 
 XcodeProj -> Project
 PBXNativeTarget -> Target
 
 For one-to-one relationship between types, the conversion is implemented by extension, and for other types, the mapping is done by functions such as generateTargetSpec.
 */
public func generateSpec(xcodeProj: XcodeProj, projectDirectory: Path) throws -> Project {
    guard let pbxproj = xcodeProj.pbxproj.rootObject else {
        throw SpecGenerationError.rootObjectNotFound
    }
    let sourceRoot = projectDirectory + pbxproj.projectDirPath

    let targets = try pbxproj.targets
        .compactMap { $0 as? PBXNativeTarget }
        .map { try generateTargetSpec(target: $0,
                                      mainGroup: pbxproj.mainGroup,
                                      sourceRoot: sourceRoot) }

    let aggregateTargets = pbxproj.targets
        .compactMap { $0 as? PBXAggregateTarget }
        .map(AggregateTarget.init)

    let configSettings = Dictionary(uniqueKeysWithValues: pbxproj.buildConfigurationList.buildConfigurations.map {
        ($0.name, Settings(buildSettings: $0.buildSettings))
    })

    let settings = Settings(buildSettings: [:], configSettings: configSettings, groups: [])

    let options = SpecOptions(defaultConfig: pbxproj.buildConfigurationList.defaultConfigurationName)

    let schems = xcodeProj.sharedData?.schemes.compactMap(Scheme.init) ?? []

    let configs = pbxproj.buildConfigurationList.buildConfigurations.map {
        Config(name: $0.name, type: $0.buildSettings.configType)
    }

    let proj = Project(basePath: Path(pbxproj.projectDirPath),
                       name: pbxproj.name,
                       configs: configs,
                       targets: targets,
                       aggregateTargets: aggregateTargets,
                       settings: settings,
                       schemes: schems,
                       options: options,
                       attributes: pbxproj.attributes
    )

    var optimizedProj = try removeDefault(project: proj, sourceRoot: sourceRoot)
    optimizedProj = deintegrateCocoapods(optimizedProj)
    optimizedProj = deintegrateCarthage(optimizedProj)

    return optimizedProj
}

private extension BuildSettings {
    var configType: ConfigType {
        guard let args = self["GCC_PREPROCESSOR_DEFINITIONS"] as? [String] else {
            return .release
        }
        return args.contains("DEBUG=1") ? .debug : .release
    }
    
    func subtracting(_ other: BuildSettings) -> BuildSettings {
        func isEqualValue(_ a: Any, _ b: Any) -> Bool {
            switch (a, b) {
            case let (a, b) as (String, String):
                return a != b
            case let (a, b) as (Bool, Bool):
                return a != b
            case let (a, b) as (Double, Double):
                return a != b
            case let (a, b) as ([Any], [Any]):
                return zip(a, b).allSatisfy(isEqualValue)
            default:
                return false
            }
        }

        return filter {
            guard let otherValue = other[$0.key] else {
                return true
            }
            return isEqualValue($0.value, otherValue)
        }
    }
}

private func generateTargetSpec(target: PBXNativeTarget, mainGroup: PBXGroup, sourceRoot: Path) throws -> Target {
    let sources = try target.sourceFiles().compactMap { fileElement -> TargetSource? in
        guard let path = try fileElement.fullPath(sourceRoot: sourceRoot) else {
            return nil
        }
        return TargetSource(path: try path.relativePath(from: sourceRoot).string,
                            name: fileElement.name)
    }

    let headers = try target.buildPhases
        .compactMap { $0 as? PBXHeadersBuildPhase }
        .compactMap { $0.files }
        .reduce([], { $0 + $1 })
        .compactMap { buildFile -> TargetSource? in
            guard let fileElement = buildFile.file,
                let path = try fileElement.fullPath(sourceRoot: sourceRoot) else {
                    return nil
            }
            let headerVisibility = TargetSource.HeaderVisibility(attribute: (buildFile.settings?["ATTRIBUTES"] as? [String])?.first)
            return TargetSource(path: try path.relativePath(from: sourceRoot).string,
                                name: fileElement.name,
                                headerVisibility: headerVisibility)
    }

    // For application targets, header files are not included in the build phase. The project should also contain header files, so search for them from groups and add to source.
    let implicitHeaders: [TargetSource]
    if let productType = target.productType, productType == .application || productType == .unitTestBundle {
        let targetRootGroup = mainGroup.children
            .compactMap { $0 as? PBXGroup }
            .first { $0.path == target.name }

        let headerFiles = targetRootGroup?.allHeaderFiles ?? []

        implicitHeaders = try headerFiles
            .compactMap { fileElement -> TargetSource? in
                guard let path = try fileElement.fullPath(sourceRoot: sourceRoot) else {
                    return nil
                }
                return TargetSource(path: try path.relativePath(from: sourceRoot).string,
                                    name: fileElement.name)
        }
    } else {
        implicitHeaders = []
    }

    let resources = try target.resourcesBuildPhase()?.files?
        .compactMap { $0.file }
        .compactMap { fileElement -> [TargetSource]? in
            if let variantGroup = fileElement as? PBXVariantGroup {
                return try variantGroup.children.compactMap { fileElement -> TargetSource? in
                    guard let parent = try fileElement.parent?.parent?.fullPath(sourceRoot: sourceRoot),
                        let path = fileElement.path else {
                        return nil
                    }
                    let fullpath = parent + path
                    return TargetSource(path: try fullpath.relativePath(from: sourceRoot).string,
                                        name: fileElement.name)
                }
            }
            guard let path = try fileElement.fullPath(sourceRoot: sourceRoot) else {
                return nil
            }
            return [TargetSource(path: try path.relativePath(from: sourceRoot).string,
                                 name: fileElement.name)]
        }.reduce([], { $0 + $1 }) ?? []

    let frameworks = target.buildPhases
        .compactMap { $0 as? PBXFrameworksBuildPhase }
        .compactMap { $0.files }
        .reduce([], { $0 + $1 })

    let targetDependencies: [Dependency] = target.dependencies.compactMap {
        guard let name = $0.target?.name else {
            return nil
        }
        return Dependency(type: .target, reference: name)
    }

    let targetDependencyProductNames = target.dependencies.compactMap { $0.target?.productNameWithExtension() }

    let frameworkDependencies: [Dependency] = frameworks.compactMap { file in
        guard let fileElement = file.file,
            let path = fileElement.path else {
                return nil
        }
        if let sourceTree = fileElement.sourceTree {
            switch sourceTree {
            case .sdkRoot:
                return Dependency(type: .sdk(root: Path(path).parent().string),
                                  reference: fileElement.name ?? Path(path).lastComponent)
            case .buildProductsDir:
                let file = Path(path).lastComponent
                if targetDependencyProductNames.contains(file) {
                    return nil // skip target dependency
                }
                return Dependency(type: .target,
                                  reference: file)
            default:
                break
            }
        }
        return Dependency(type: .framework, reference: path)
    }

    let dependencies = targetDependencies + frameworkDependencies

    let targetSources = sources + headers + implicitHeaders + resources

    var preBuildScripts = [BuildScript]()
    var postCompileScripts: [BuildScript]?
    var postBuildScripts: [BuildScript]?

    for buildPhase in target.buildPhases {
        if postBuildScripts != nil {
            if let buildPhase = buildPhase as? PBXShellScriptBuildPhase {
                postBuildScripts?.append(BuildScript(buildPhase: buildPhase))
            }
        } else if postCompileScripts != nil {
            // Scripts between the compile and non-script phases
            if let buildPhase = buildPhase as? PBXShellScriptBuildPhase {
                postCompileScripts?.append(BuildScript(buildPhase: buildPhase))
            } else {
                postBuildScripts = [BuildScript]()
            }
        } else {
            // Script before the compile phase
            if buildPhase is PBXSourcesBuildPhase {
                postCompileScripts = [BuildScript]()
            } else if let buildPhase = buildPhase as? PBXShellScriptBuildPhase {
                preBuildScripts.append(BuildScript(buildPhase: buildPhase))
            }
        }
    }

    let buildRules = target.buildRules.map(BuildRule.init)

    let sdkRoot = target.settings.buildSettings["SDKROOT"] as? String
    let platform = Platform.allCases.first { $0.sdkRoot == sdkRoot } ?? .iOS

    return Target(name: target.name,
                  type: target.productType ?? .application,
                  platform: platform,
                  productName: target.productName,
                  settings: target.settings,
                  sources: targetSources,
                  dependencies: dependencies,
                  preBuildScripts: preBuildScripts,
                  postCompileScripts: postCompileScripts ?? [],
                  postBuildScripts: postBuildScripts ?? [],
                  buildRules: buildRules)
}

// MARK: - Cleaning the spec

private func removeDefault(project: Project, sourceRoot: Path) throws -> Project {
    func removeDefaultsFromProjectSettings(_ settings: Settings) -> Settings {
        var newSettings = settings

        for case (let key, var settings) in newSettings.configSettings {
            let variant = BuildSettingsProvider.Variant(key) ?? .debug
            let defaultSettings = BuildSettingsProvider.projectDefault(variant: .all)
                .merged(BuildSettingsProvider.projectDefault(variant: variant))
            settings.buildSettings = settings.buildSettings.subtracting(defaultSettings)
            newSettings.configSettings[key] = settings
        }

        return newSettings
    }

    func removeDefaultsFromTargetSettings(_ settings: Settings, in target: Target) -> Settings {
        var newSettings = settings

        for case (let key, var settings) in newSettings.configSettings {
            let variant = BuildSettingsProvider.Variant(key) ?? .debug

            let projectBuildSettings = project.settings.configSettings[key]?.buildSettings
            let sdkRoot = projectBuildSettings?["SDKROOT"] as? String
            let platform = BuildSettingsProvider.Platform(sdkRoot: sdkRoot)
            let product = BuildSettingsProvider.Product(product: target.type)
            let swift = projectBuildSettings?["SWIFT_OPTIMIZATION_LEVEL"] as? String != nil

            let defaultSettings = BuildSettingsProvider.projectDefault(variant: .all)
                .merged(BuildSettingsProvider.targetDefault(
                    variant: variant,
                    platform: platform,
                    product: product,
                    swift: swift))

            settings.buildSettings = settings.buildSettings.subtracting(defaultSettings)
            newSettings.configSettings[key] = settings
        }

        return newSettings
    }

    var project = project
    project.settings = removeDefaultsFromProjectSettings(project.settings)
    project.targets = try project.targets.map { target in
        var target = target
        target.settings = removeDefaultsFromTargetSettings(target.settings, in: target)
        target.sources = try optimizeSources(target.sources, sourceRoot: sourceRoot)
        return target
    }

    return project
}

private func optimizeSources(_ sources: [TargetSource], sourceRoot: Path) throws -> [TargetSource] {
    let allSourcePaths = sources.map { sourceRoot + Path($0.path) }
    var merged = [TargetSource]()

    let completed = try sources
        .sorted { Path($0.path).components.count > Path($1.path).components.count }
        .compactMap { targetSource -> TargetSource? in
            let parent = (sourceRoot + Path(targetSource.path)).parent()

            // skip when parent directory is already added
            if merged.contains(where: { (sourceRoot + Path($0.path)) == parent }) {
                return nil
            }

            let sameLevelFiles = try parent.children().filter {
                // ingore files that will specified in build configs
                $0.lastComponent != "Info.plist" &&
                    $0.lastComponent != ".DS_Store" &&
                    $0.extension != "modulemap" &&
                    $0.extension != "entitlements"
            }

            // merge files into a directory if all its contents are in the target
            if sameLevelFiles.allSatisfy({ allSourcePaths.contains($0) }) {
                merged.append(TargetSource(path: try parent.relativePath(from: sourceRoot).string,
                                           name: parent.lastComponent))
                return nil
            }
            return targetSource
    }

    let result = merged.count > 0 ? try optimizeSources(completed + merged, sourceRoot: sourceRoot) : completed
    return result.sorted { $0.path < $1.path }
}

// MARK: - Cocoapods/Carthage deintegration

private extension PBXGroup {
    var allHeaderFiles: [PBXFileElement] {
        return children.compactMap { file in
            if let group = file as? PBXGroup {
                return group.allHeaderFiles
            }

            if let path = file.path,
                path.hasSuffix(".h") || path.hasSuffix(".hpp") {
                return [file]
            }

            return nil
        }.reduce([], { $0 + $1 })
    }
}

private func deintegrateCocoapods(_ project: Project) -> Project {
    var p = project
    p.targets = p.targets.map(deintegrateCocoapods)
    return p
}

private func not<T>(_ fn: @escaping (T) -> Bool) -> (T) -> Bool {
    return { v in !fn(v) }
}

private func deintegrateCocoapods(target: Target) -> Target {
    func isCocoapodsBuildScript(buildScript: BuildScript) -> Bool {
        // https://github.com/CocoaPods/CocoaPods/blob/master/lib/cocoapods/installer/user_project_integrator/target_integrator.rb#L16
        return buildScript.name?.starts(with: "[CP] ") ?? false
    }

    var t = target

    t.preBuildScripts = target.preBuildScripts.filter(not(isCocoapodsBuildScript))
    t.postCompileScripts = target.postCompileScripts.filter(not(isCocoapodsBuildScript))
    t.postBuildScripts = target.postBuildScripts.filter(not(isCocoapodsBuildScript))

    // https://github.com/CocoaPods/cocoapods-deintegrate/blob/master/lib/cocoapods/deintegrator.rb#L5
    let frameworkNames = try! NSRegularExpression(pattern: "^(libPods.*\\.a)|(Pods.*\\.framework)$")
    t.dependencies = t.dependencies.filter {
        !frameworkNames.isMatch(to: $0.reference)
    }

    return t
}

private func deintegrateCarthage(_ project: Project) -> Project {
    var p = project
    p.targets = p.targets.map(deintegrateCarthage)
    return p
}

private func deintegrateCarthage(target: Target) -> Target {
    func isCarthageBuildScript(buildScript: BuildScript) -> Bool {
        guard case .script(let script) = buildScript.script else {
            return false
        }
        return script.contains("carthage copy-frameworks")
    }

    var t = target

    t.preBuildScripts = target.preBuildScripts.filter(not(isCarthageBuildScript))
    t.postCompileScripts = target.postCompileScripts.filter(not(isCarthageBuildScript))
    t.postBuildScripts = target.postBuildScripts.filter(not(isCarthageBuildScript))

    t.dependencies = t.dependencies.map {
        if $0.reference.starts(with: "Carthage/Build/") {
            return Dependency(
                type: .carthage(findFrameworks: nil,
                                linkType: .default),
                reference: Path($0.reference).lastComponentWithoutExtension
            )
        }
        return $0
    }
    
    let frameworkSearchPaths = "FRAMEWORK_SEARCH_PATHS"
    for key in t.settings.configSettings.keys {
        if let searchPaths = t.settings.configSettings[key]?.buildSettings[frameworkSearchPaths] as? [String] {
            t.settings.configSettings[key]?.buildSettings[frameworkSearchPaths] = searchPaths.filter {
                !$0.starts(with: "$(PROJECT_DIR)/Carthage/Build")
            }
        }
    }

    return t
}

// MARK: - Extensions for type conversion

private extension BuildSettingsProvider.Variant {
    init(_ configType: ConfigType) {
        switch configType {
        case .debug: self = .debug
        case .release: self = .release
        }
    }
}

private extension BuildSettingsProvider.Product {
    init?(product: PBXProductType) {
        switch product {
        case .bundle:
            self = .bundle
        case .application, .messagesApplication, .watch2App, .watchApp:
            self = .application
        case .framework, .staticFramework:
            self = .framework
        case .uiTestBundle:
            self = .uiTests
        case .unitTestBundle:
            self = .unitTests
        default:
            return nil
        }
    }
}

private extension BuildSettingsProvider.Platform {
    init?(sdkRoot: String?) {
        guard let sdkRoot = sdkRoot else {
            return nil
        }
        switch sdkRoot {
        case "iphoneos": self = .iOS
        case "appletvos": self = .tvOS
        case "watchos": self = .watchOS
        case "macosx": self = .macOS
        default: return nil
        }
    }
}

private extension BuildSettingsProvider.Variant {
    init?(_ string: String) {
        switch string {
        case "Debug":
            self = .debug
        case "Release":
            self = .release
        default:
            return nil
        }
    }
}

private extension BuildScript {
    init(buildPhase: PBXShellScriptBuildPhase) {
        self.init(script: .script(buildPhase.shellScript ?? ""),
                  name: buildPhase.name,
                  inputFiles: buildPhase.inputPaths,
                  outputFiles: buildPhase.outputPaths,
                  inputFileLists: buildPhase.inputFileListPaths ?? [],
                  outputFileLists: buildPhase.outputFileListPaths ?? [],
                  shell: buildPhase.shellPath,
                  runOnlyWhenInstalling: buildPhase.runOnlyForDeploymentPostprocessing,
                  showEnvVars: buildPhase.showEnvVarsInLog)
    }
}

private extension PBXTarget {
    var settings: Settings {
        let configSettings = buildConfigurationList?.buildConfigurations.map {
            ($0.name, Settings(buildSettings: $0.buildSettings))
        }

        return Settings(configSettings: configSettings.flatMap(Dictionary.init) ?? [:])
    }
}

private extension AggregateTarget {
    init(target: PBXAggregateTarget) {
        let buildScripts = target.buildPhases
            .compactMap { $0 as? PBXShellScriptBuildPhase }
            .map(BuildScript.init)

        self.init(
            name: target.name,
            targets: target.dependencies.compactMap { $0.target?.name },
            settings: target.settings,
            buildScripts: buildScripts)
    }
}

private extension BuildRule {
    init(buildRule: PBXBuildRule) {
        let fileType: BuildRule.FileType
        if let filePatterns = buildRule.filePatterns {
            fileType = .pattern(filePatterns)
        } else {
            fileType = .type(buildRule.fileType)
        }

        let compilerSpec: BuildRule.Action
        if buildRule.compilerSpec == "com.apple.compilers.proxy.script" {
            compilerSpec = .script(buildRule.script ?? "")
        } else {
            compilerSpec = .compilerSpec(buildRule.compilerSpec)
        }

        self.init(fileType: fileType,
                  action: compilerSpec,
                  name: buildRule.name,
                  outputFiles: buildRule.outputFiles,
                  outputFilesCompilerFlags: buildRule.outputFilesCompilerFlags ?? [])
    }
}

private extension TargetSource.HeaderVisibility {
    init?(attribute: String?) {
        guard let attribute = attribute else {
            return nil
        }
        switch attribute {
        case TargetSource.HeaderVisibility.private.settingName:
            self = .private
        case TargetSource.HeaderVisibility.public.settingName:
            self = .public
        case TargetSource.HeaderVisibility.project.settingName:
            self = .project
        default:
            return nil
        }
    }
}

private extension Scheme {
    init?(scheme: XCScheme) {
        guard let buildAction = scheme.buildAction,
              let buildableReference = buildAction.buildActionEntries.first?.buildableReference else {
            return nil
        }
        self.init(
            name: scheme.name,
            build: Scheme.Build(
                targets: [BuildTarget(target: TestableTargetReference(name: buildableReference.blueprintName, location: .local))],
                parallelizeBuild: buildAction.parallelizeBuild,
                buildImplicitDependencies: buildAction.buildImplicitDependencies,
                preActions: buildAction.preActions.map(Scheme.ExecutionAction.init),
                postActions: buildAction.postActions.map(Scheme.ExecutionAction.init)
            ),
            run: scheme.launchAction.flatMap { launchAction in
                Scheme.Run(
                    config: launchAction.buildConfiguration,
                    executable: launchAction.runnable?.buildableReference?.blueprintName,
                    commandLineArguments: launchAction.commandlineArguments?.toDictionary() ?? [:],
                    preActions: launchAction.preActions.map(Scheme.ExecutionAction.init),
                    postActions: launchAction.postActions.map(Scheme.ExecutionAction.init),
                    environmentVariables: launchAction.environmentVariables ?? [],
                    disableMainThreadChecker: launchAction.disableMainThreadChecker,
                    stopOnEveryMainThreadCheckerIssue: launchAction.stopOnEveryMainThreadCheckerIssue,
                    language: launchAction.language,
                    region: launchAction.region,
                    askForAppToLaunch: launchAction.askForAppToLaunch,
                    launchAutomaticallySubstyle: launchAction.launchAutomaticallySubstyle,
                    debugEnabled: !launchAction.selectedDebuggerIdentifier.isEmpty,
                    simulateLocation: launchAction.locationScenarioReference.flatMap {
                        SimulateLocation(allow: launchAction.allowLocationSimulation,
                                         defaultLocation: $0.identifier)
                    },
                    customLLDBInit: launchAction.customLLDBInitFile)
            },
            test: scheme.testAction.flatMap { testAction in
                let targets = testAction.testables.map {
                    Scheme.Test.TestTarget(
                        targetReference: TestableTargetReference(
                            name: $0.buildableReference.blueprintName,
                            location: .local),
                        randomExecutionOrder: $0.parallelizable,
                        parallelizable: $0.parallelizable,
                        skipped: $0.skipped,
                        skippedTests: $0.skippedTests.map { $0.identifier })
                }

                return Scheme.Test(
                    config: testAction.buildConfiguration,
                    gatherCoverageData: testAction.codeCoverageEnabled,
                    coverageTargets: testAction.codeCoverageTargets.map {
                        TestableTargetReference(name: $0.blueprintName, location: .local)
                    },
                    disableMainThreadChecker: testAction.disableMainThreadChecker,
                    randomExecutionOrder: targets.allSatisfy { $0.randomExecutionOrder },
                    parallelizable: targets.allSatisfy { $0.parallelizable },
                    commandLineArguments: testAction.commandlineArguments?.toDictionary() ?? [:],
                    targets: targets,
                    preActions: testAction.preActions.map(Scheme.ExecutionAction.init),
                    postActions: testAction.postActions.map(Scheme.ExecutionAction.init),
                    environmentVariables: testAction.environmentVariables ?? [],
                    language: testAction.language,
                    region: testAction.region,
                    debugEnabled: !testAction.selectedDebuggerIdentifier.isEmpty,
                    customLLDBInit: testAction.customLLDBInitFile)
            },
            profile: scheme.profileAction.flatMap {
                Scheme.Profile(
                    config: $0.buildConfiguration,
                    commandLineArguments: $0.commandlineArguments?.toDictionary() ?? [:],
                    preActions: $0.preActions.map(Scheme.ExecutionAction.init),
                    postActions: $0.postActions.map(Scheme.ExecutionAction.init),
                    environmentVariables: $0.environmentVariables ?? [])
            },
            analyze: scheme.analyzeAction.flatMap {
                Scheme.Analyze(config: $0.buildConfiguration)
            },
            archive: scheme.archiveAction.flatMap {
                Scheme.Archive(
                    config: $0.buildConfiguration,
                    customArchiveName: $0.customArchiveName,
                    revealArchiveInOrganizer: $0.revealArchiveInOrganizer,
                    preActions: $0.preActions.map(Scheme.ExecutionAction.init),
                    postActions: $0.postActions.map(Scheme.ExecutionAction.init))
            })
    }
}

private extension Scheme.ExecutionAction {
    init(action: XCScheme.ExecutionAction) {
        self.init(
            name: action.title,
            script: action.scriptText,
            settingsTarget: action.environmentBuildable?.blueprintName
        )
    }
}

private extension XCScheme.CommandLineArguments {
    func toDictionary() -> Dictionary<String, Bool> {
        return Dictionary(uniqueKeysWithValues: arguments.map { ($0.name, $0.enabled) })
    }
}
