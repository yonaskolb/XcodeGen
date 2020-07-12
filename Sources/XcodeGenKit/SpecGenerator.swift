import Foundation
import ProjectSpec
import XcodeProj
import PathKit

public func generateSpec(xcodeProj: XcodeProj, projectDirectory: Path) throws -> Project? {
    guard let pbxproj = xcodeProj.pbxproj.rootObject else {
        return nil
    }
    return try generateProjectSpec(pbxproj: pbxproj, projectDirectory: projectDirectory)
}

private func generateProjectSpec(pbxproj: PBXProject, projectDirectory: Path) throws -> Project {
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

    let proj = Project(basePath: Path(pbxproj.projectDirPath),
                       name: pbxproj.name,
                       targets: targets,
                       aggregateTargets: aggregateTargets,
                       settings: settings,
                       options: options,
                       attributes: pbxproj.attributes)

    return try removeDefault(project: proj, sourceRoot: sourceRoot)
}

private extension BuildSettingsProvider.Variant {
    init(_ configType: ConfigType) {
        switch configType {
        case .debug: self = .debug
        case .release: self = .release
        }
    }
}

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

    func optimizeSources(_ sources: [TargetSource], sourceRoot: Path) throws -> [TargetSource] {
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

private extension BuildSettings {
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

    let buildScripts = target.buildPhases
        .compactMap { $0 as? PBXShellScriptBuildPhase }
        .map(BuildScript.init)

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
                  postBuildScripts: buildScripts,
                  buildRules: buildRules)
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

extension PBXGroup {
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
