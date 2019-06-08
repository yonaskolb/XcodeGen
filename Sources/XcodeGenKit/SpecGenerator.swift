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
    let targets = try pbxproj.targets
        .compactMap { $0 as? PBXNativeTarget }
        .map { try generateTargetSpec(target: $0,
                                      mainGroup: pbxproj.mainGroup,
                                      sourceRoot: projectDirectory + pbxproj.projectDirPath) }

    let aggregateTargets = pbxproj.targets
        .compactMap { $0 as? PBXAggregateTarget }
        .map(AggregateTarget.init)

    return Project(basePath: Path(pbxproj.projectDirPath),
                   name: pbxproj.name,
                   targets: targets,
                   aggregateTargets: aggregateTargets,
                   settingGroups: pbxproj.settingGroups,
                   options: .init(),
                   attributes: pbxproj.attributes)
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
        .compactMap { $0.files?.compactMap { $0.file } }
        .reduce([], { $0 + $1 })

    let dependencies: [Dependency] = frameworks.compactMap { fileElement in
        guard let path = fileElement.path else {
            return nil
        }
        if let sourceTree = fileElement.sourceTree, sourceTree == .sdkRoot {
            return Dependency(type: .sdk(root: Path(path).parent().string),
                              reference: fileElement.name ?? Path(path).lastComponent)
        }
        return Dependency(type: .framework, reference: path)
    }

    let targetSources = sources + headers + implicitHeaders + resources

    let buildScripts = target.buildPhases
        .compactMap { $0 as? PBXShellScriptBuildPhase }
        .map(BuildScript.init)

    let buildRules = target.buildRules.map(BuildRule.init)

    return Target(name: target.name,
                  type: target.productType ?? .application,
                  platform: .iOS,
                  productName: target.productName,
                  settings: target.settings,
                  sources: try optimizeSources(targetSources, sourceRoot: sourceRoot),
                  dependencies: dependencies,
                  postBuildScripts: buildScripts,
                  buildRules: buildRules)
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

private extension PBXProject {
    var settingGroups: [String: Settings] {
        return Dictionary(uniqueKeysWithValues: buildConfigurationList.buildConfigurations.map {
            ($0.name, Settings(buildSettings: $0.buildSettings))
        })
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
