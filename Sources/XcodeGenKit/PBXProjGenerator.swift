//
//  PBXProjGenerator.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 23/7/17.
//
//

import Foundation
import Foundation
import PathKit
import xcodeproj
import xcodeprojprotocols
import JSONUtilities
import Yams

public class PBXProjGenerator {

    let spec: Spec
    let basePath: Path

    var objects: [PBXObject] = []
    var fileReferencesByPath: [Path: String] = [:]
    var groupsByPath: [Path: PBXGroup] = [:]

    var targetNativeReferences: [String: String] = [:]
    var targetBuildFileReferences: [String: String] = [:]
    var targetFileReferences: [String: String] = [:]
    var topLevelGroups: [PBXGroup] = []
    var carthageFrameworksByPlatform: [String: [String]] = [:]
    var frameworkFiles: [String] = []
    let generatedConfigs: [Config]

    var ids = 0
    var projectReference: String

    public init(spec: Spec, path: Path) {
        self.spec = spec
        self.basePath = path
        
        if spec.configVariants.isEmpty {
            generatedConfigs = spec.configs
        } else {
            generatedConfigs = spec.configs.reduce([]) { all, config in
                all + spec.configVariants.map { variant in
                    let name = "\(variant) \(config.name)"
                    return Config(name: name, type: config.type, buildSettingGroups: config.buildSettingGroups, buildSettings: config.buildSettings)
                }
            }
        }

        projectReference = ""
        projectReference = id()
    }

    func id() -> String {
        ids += 1
        //        return ids.description.md5().uppercased()
        return "OBJECT_\(ids)"
    }

    public func generate() throws -> PBXProj {
        let buildConfigs: [XCBuildConfiguration] = try generatedConfigs.map { config in

            var buildSettings = config.buildSettings
            if let type = config.type, let typeBuildSettings = try BuildSettingsPreset.config(type).getBuildSettings() {
                buildSettings = typeBuildSettings.merged(buildSettings)
            }
            return XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: nil, buildSettings: buildSettings)
        }

        let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: buildConfigs.referenceSet, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

        objects += buildConfigs.map { .xcBuildConfiguration($0) }
        objects.append(.xcConfigurationList(buildConfigList))

        for target in spec.targets {
            targetNativeReferences[target.name] = id()

            let fileReference = PBXFileReference(reference: id(), sourceTree: .buildProductsDir, explicitFileType: target.type.fileExtension, path: target.filename, includeInIndex: 0)
            objects.append(.pbxFileReference(fileReference))
            targetFileReferences[target.name] = fileReference.reference

            let buildFile = PBXBuildFile(reference: id(), fileRef: fileReference.reference)
            objects.append(.pbxBuildFile(buildFile))
            targetBuildFileReferences[target.name] = buildFile.reference
        }

        let targets = try spec.targets.map(generateTarget)

        let productGroup = PBXGroup(reference: id(), children: Array(targetFileReferences.values), sourceTree: .group, name: "Products")
        objects.append(.pbxGroup(productGroup))
        topLevelGroups.append(productGroup)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup = PBXGroup(reference: id(), children: fileReferences, sourceTree: .group, name: platform, path: platform)
                objects.append(.pbxGroup(platformGroup))
                platforms.append(platformGroup)
            }
            let carthageGroup = PBXGroup(reference: id(), children: platforms.referenceList, sourceTree: .group, name: "Carthage", path: "Carthage/Build")
            objects.append(.pbxGroup(carthageGroup))
            topLevelGroups.append(carthageGroup)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(reference: id(), children: frameworkFiles, sourceTree: .group, name: "Frameworks")
            objects.append(.pbxGroup(group))
            topLevelGroups.append(group)
        }

        let mainGroup = PBXGroup(reference: id(), children: topLevelGroups.referenceList, sourceTree: .group)
        objects.append(.pbxGroup(mainGroup))

        let knownRegions: [String] = ["en", "Base"]
        let pbxProjectRoot = PBXProject(reference: projectReference, buildConfigurationList: buildConfigList.reference, compatibilityVersion: "Xcode 3.2", mainGroup: mainGroup.reference, developmentRegion: "English", knownRegions: knownRegions, targets: targets.referenceList)
        objects.append(.pbxProject(pbxProjectRoot))

        return PBXProj(archiveVersion: 1, objectVersion: 46, rootObject: projectReference, objects: objects)
    }

    struct SourceFile {
        let path: Path
        let fileReference: String
        let buildFile: PBXBuildFile
    }

    func generateSourceFile(path: Path) -> SourceFile {
        let fileReference = fileReferencesByPath[path]!
        var settings: [String: Any] = [:]
        if getBuildPhaseForPath(path) == .headers {
            settings["ATTRIBUTES"] = ["Public"]
        }
        let buildFile = PBXBuildFile(reference: id(), fileRef: fileReference, settings: settings)
        objects.append(.pbxBuildFile(buildFile))
        return SourceFile(path: path, fileReference: fileReference, buildFile: buildFile)
    }

    func generateTarget(_ target: Target) throws -> PBXNativeTarget  {

        let sourcePaths = target.sources.map { basePath + $0 }
        var sourceFilePaths: [Path] = []

        for source in sourcePaths {
            let sourceGroups = try getGroups(path: source, groupReference: id())
            sourceFilePaths += sourceGroups.filePaths
        }

        let configs: [XCBuildConfiguration] = try generatedConfigs.map { config in
            let buildSettings = try getTargetBuildSettings(config: config.name, target: target)
            var baseConfigurationReference: String?
            if let configPath = target.configs[config.name] {
                let path = basePath + configPath
                baseConfigurationReference = fileReferencesByPath[path]
            }
            return XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }
        objects += configs.map { .xcBuildConfiguration($0) }
        let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: configs.referenceSet, defaultConfigurationName: "")
        objects.append(.xcConfigurationList(buildConfigList))

        var dependancies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFiles: [String] = []
        for dependancy in target.dependencies {
            switch dependancy {
            case let .target(dependencyTarget):
                let targetProxy = PBXContainerItemProxy(reference: id(), containerPortal: projectReference, remoteGlobalIDString: targetNativeReferences[dependencyTarget]!, proxyType: .nativeTarget, remoteInfo: dependencyTarget)
                let targetDependancy = PBXTargetDependency(reference: id(), target: targetNativeReferences[dependencyTarget]!, targetProxy: targetProxy.reference )

                objects.append(.pbxContainerItemProxy(targetProxy))
                objects.append(.pbxTargetDependency(targetDependancy))
                dependancies.append(targetDependancy.reference)

                let dependencyBuildFile = targetBuildFileReferences[dependencyTarget]!
                //link
                targetFrameworkBuildFiles.append(dependencyBuildFile)

                //embed
                let embedSettings: [String: Any] = ["ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]]
                let embedFile = PBXBuildFile(reference: id(), fileRef: targetFileReferences[dependencyTarget]!, settings: embedSettings)
                objects.append(.pbxBuildFile(embedFile))
                copyFiles.append(embedFile.reference)
            case let .framework(framework):
                let fileReference = getFileReference(path: Path(framework), inPath: basePath)
                let buildFile = PBXBuildFile(reference: id(), fileRef: fileReference)
                objects.append(.pbxBuildFile(buildFile))
                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }
            case let .carthage(carthage):
                if carthageFrameworksByPlatform[target.platform.rawValue] == nil {
                    carthageFrameworksByPlatform[target.platform.rawValue] = []
                }
                let carthagePath: Path = "Carthage/Build"
                var platformPath = carthagePath + target.platform.rawValue
                var frameworkPath = platformPath + carthage
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(reference: id(), fileRef: fileReference)
                objects.append(.pbxBuildFile(buildFile))
                carthageFrameworksByPlatform[target.platform.rawValue]?.append(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        if target.type == .framework {
            let buildFile = PBXBuildFile(reference: targetBuildFileReferences[target.name]!, fileRef: fileReference)
            objects.append(.pbxBuildFile(buildFile))
        }

        //TODO: don't generate build files for files that won't be built

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> Set<String> {
            let files = sourceFilePaths.filter { getBuildPhaseForPath($0) == buildPhase }.map(generateSourceFile)
            return Set(files.map { $0.buildFile.reference })
        }

        let sourcesBuildPhase = PBXSourcesBuildPhase(reference: id(), files: getBuildFilesForPhase(.sources))
        objects.append(.pbxSourcesBuildPhase(sourcesBuildPhase))
        buildPhases.append(sourcesBuildPhase.reference)

        let resourcesBuildPhase = PBXResourcesBuildPhase(reference: id(), files: getBuildFilesForPhase(.resources))
        objects.append(.pbxResourcesBuildPhase(resourcesBuildPhase))
        buildPhases.append(resourcesBuildPhase.reference)

        let headersBuildPhase = PBXHeadersBuildPhase(reference: id(), files: getBuildFilesForPhase(.headers))
        objects.append(.pbxHeadersBuildPhase(headersBuildPhase))
        buildPhases.append(headersBuildPhase.reference)

        let frameworkBuildPhase = PBXFrameworksBuildPhase(reference: id(), files: Set(targetFrameworkBuildFiles), runOnlyForDeploymentPostprocessing: 0)
        objects.append(.pbxFrameworksBuildPhase(frameworkBuildPhase))
        buildPhases.append(frameworkBuildPhase.reference)

        let copyFilesPhase = PBXCopyFilesBuildPhase(reference: id(), dstPath: "", dstSubfolderSpec: .frameworks, files: Set(copyFiles))
        objects.append(.pbxCopyFilesBuildPhase(copyFilesPhase))
        buildPhases.append(copyFilesPhase.reference)


        if target.type == .application {
            func getCarthageFrameworks(target: Target) -> [String] {
                var frameworks: [String] = []
                for dependency in target.dependencies {
                    switch dependency {
                    case .carthage(let framework): frameworks.append(framework)
                    case .target(let targetName):
                        if let target = spec.targets.first(where: {$0.name == targetName}) {
                            frameworks += getCarthageFrameworks(target: target)
                        }
                    default: break
                    }
                }
                return frameworks
            }

            let carthageFrameworks = Set(getCarthageFrameworks(target: target))
            if !carthageFrameworks.isEmpty {
                let inputPaths = carthageFrameworks.map { "$(SRCROOT)/Carthage/Build/\(target.platform)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let carthageScript = PBXShellScriptBuildPhase(reference: id(), files: [], name: "Carthage", inputPaths: Set(inputPaths), outputPaths: [], shellPath: "/bin/sh", shellScript: "/usr/local/bin/carthage copy-frameworks\n")
                objects.append(.pbxShellScriptBuildPhase(carthageScript))
                buildPhases.append(carthageScript.reference)
            }
        }

        let nativeTarget = PBXNativeTarget(
            reference: targetNativeReferences[target.name]!,
            buildConfigurationList: buildConfigList.reference,
            buildPhases: buildPhases,
            buildRules: [],
            dependencies: dependancies,
            name: target.name,
            productReference: fileReference,
            productType: target.type)
        objects.append(.pbxNativeTarget(nativeTarget))
        return nativeTarget
    }

    func getBuildPhaseForPath(_ path: Path) -> BuildPhase? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "swift", "m": return .sources
            case "h", "hh", "hpp", "ipp", "tpp", "hxx", "def": return .headers
            case "xcconfig": return nil
            default: return .resources
            }
        }
        return nil
    }

    func getTargetBuildSettings(config: String, target: Target) throws -> BuildSettings {
        var buildSettings = BuildSettings()

        func getBuildSettingPreset(_ type: BuildSettingsPreset) throws -> BuildSettings? {
            return try type.getBuildSettings()
        }

        buildSettings += try getBuildSettingPreset(.base)
        buildSettings += try getBuildSettingPreset(.platform(target.platform))
        buildSettings += try getBuildSettingPreset(.product(target.type))
        buildSettings += target.buildSettings?.buildSettings
        buildSettings += target.buildSettings?.configSettings[config]

        return buildSettings
    }

    func getFileReference(path: Path, inPath: Path) -> String {
        if let fileReference = fileReferencesByPath[path] {
            return fileReference
        } else {
            let fileReference = PBXFileReference(reference: id(), sourceTree: .group, path: path.byRemovingBase(path: inPath).string)
            objects.append(.pbxFileReference(fileReference))
            fileReferencesByPath[path] = fileReference.reference
            return fileReference.reference
        }
    }

    func getGroups(path: Path, groupReference: String, depth: Int = 0) throws -> (filePaths: [Path], groups: [PBXGroup]) {

        let directories = try path.children().filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }
        var filePaths = try path.children().filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }
        let localisedDirectories = try path.children().filter { $0.extension == "lproj" }
        var groupChildren: [String] = []
        var allFilePaths: [Path] = filePaths
        var groups: [PBXGroup] = []

        let childGroupReference = directories.map { _ in id() }
        for (reference, path) in zip(childGroupReference,directories) {
            let subGroups = try getGroups(path: path, groupReference: reference, depth: depth + 1)
            allFilePaths += subGroups.filePaths
            groupChildren.append(subGroups.groups.first!.reference)
            groups += subGroups.groups
        }

        for filePath in filePaths {
            let fileReference = getFileReference(path: filePath, inPath: path)
            groupChildren.append(fileReference)
        }

        for localisedDirectory in localisedDirectories {
            for path in try localisedDirectory.children() {
                let filePath = "\(localisedDirectory.lastComponent)/\(path.lastComponent)"
                let fileReference = PBXFileReference(reference: id(), sourceTree: .group, name: localisedDirectory.lastComponentWithoutExtension, path: filePath)
                objects.append(.pbxFileReference(fileReference))

                let variantGroup = PBXVariantGroup(reference: id(), children: Set([fileReference.reference]), name: path.lastComponent, sourceTree: .group)
                objects.append(.pbxVariantGroup(variantGroup))

                fileReferencesByPath[path] = variantGroup.reference
                groupChildren.append(variantGroup.reference)
                filePaths.append(path)
            }
        }

        let groupPath: String = depth == 0 ? path.byRemovingBase(path: basePath).string : path.lastComponent
        let group: PBXGroup
        if let cachedGroup = groupsByPath[path] {
            group = cachedGroup
        } else {
            group = PBXGroup(reference: groupReference, children: groupChildren, sourceTree: .group, name: path.lastComponent, path: groupPath)
            objects.append(.pbxGroup(group))
            if depth == 0 {
                topLevelGroups.append(group)
            }
            groupsByPath[path] = group
        }
        groups.insert(group, at: 0)
        return (allFilePaths, groups)
    }

}
