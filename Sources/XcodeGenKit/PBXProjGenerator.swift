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
import JSONUtilities
import Yams
import ProjectSpec

public class PBXProjGenerator {

    let spec: ProjectSpec
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

    var uuids: Set<String> = []
    var projectReference: String

    public init(spec: ProjectSpec, path: Path) {
        self.spec = spec
        basePath = path

        projectReference = ""
        projectReference = generateUUID(PBXProject.self, spec.name)
    }

    public func generateUUID<T: ProjectElement>(_ element: T.Type, _ id: String) -> String {
        var uuid: String = ""
        var counter: UInt = 0
        let className: String = String(describing: T.self).replacingOccurrences(of: "PBX", with: "")
        let classAcronym = String(className.characters.filter { String($0).lowercased() != String($0) })
        let stringID = String(abs(id.hashValue).description.characters.prefix(10 - classAcronym.characters.count))
        repeat {
            counter += 1
            uuid = "\(classAcronym)\(stringID)\(String(format: "%02d", counter))"
        } while (uuids.contains(uuid))
        uuids.insert(uuid)
        return uuid
    }

    public func generate() throws -> PBXProj {
        uuids = []
        let buildConfigs: [XCBuildConfiguration] = spec.configs.map { config in
            let buildSettings = spec.getProjectBuildSettings(config: config)
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name), name: config.name, baseConfigurationReference: nil, buildSettings: buildSettings)
        }

        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, spec.name), buildConfigurations: buildConfigs.referenceSet, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

        objects += buildConfigs.map { .xcBuildConfiguration($0) }
        objects.append(.xcConfigurationList(buildConfigList))

        for target in spec.targets {
            targetNativeReferences[target.name] = generateUUID(PBXNativeTarget.self, target.name)

            let fileReference = PBXFileReference(reference: generateUUID(PBXFileReference.self, target.name), sourceTree: .buildProductsDir, explicitFileType: target.type.fileExtension, path: target.filename, includeInIndex: 0)
            objects.append(.pbxFileReference(fileReference))
            targetFileReferences[target.name] = fileReference.reference

            let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference.reference), fileRef: fileReference.reference)
            objects.append(.pbxBuildFile(buildFile))
            targetBuildFileReferences[target.name] = buildFile.reference
        }

        let targets = try spec.targets.map(generateTarget)

        let productGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Products"), children: Array(targetFileReferences.values), sourceTree: .group, name: "Products")
        objects.append(.pbxGroup(productGroup))
        topLevelGroups.append(productGroup)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup = PBXGroup(reference: generateUUID(PBXGroup.self, platform), children: fileReferences, sourceTree: .group, name: platform, path: platform)
                objects.append(.pbxGroup(platformGroup))
                platforms.append(platformGroup)
            }
            let carthageGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Carthage"), children: platforms.referenceList, sourceTree: .group, name: "Carthage", path: "Carthage/Build")
            objects.append(.pbxGroup(carthageGroup))
            topLevelGroups.append(carthageGroup)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(reference: generateUUID(PBXGroup.self, "Frameworks"), children: frameworkFiles, sourceTree: .group, name: "Frameworks")
            objects.append(.pbxGroup(group))
            topLevelGroups.append(group)
        }

        let mainGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Project"), children: topLevelGroups.referenceList, sourceTree: .group)
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
        var settings: [String: Any]?
        if getBuildPhaseForPath(path) == .headers {
            settings = ["ATTRIBUTES": ["Public"]]
        }
        let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference), fileRef: fileReference, settings: settings)
        objects.append(.pbxBuildFile(buildFile))
        return SourceFile(path: path, fileReference: fileReference, buildFile: buildFile)
    }

    func generateTarget(_ target: Target) throws -> PBXNativeTarget {

        let sourcePaths = target.sources.map { basePath + $0 }
        var sourceFilePaths: [Path] = []

        for source in sourcePaths {
            let sourceGroups = try getGroups(path: source)
            sourceFilePaths += sourceGroups.filePaths
        }

        let configs: [XCBuildConfiguration] = spec.configs.map { config in
            let buildSettings = spec.getTargetBuildSettings(target: target, config: config)
            var baseConfigurationReference: String?

            if let configPath = target.configFiles[config.name] {
                let path = basePath + configPath
                baseConfigurationReference = fileReferencesByPath[path]
            }
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name + target.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }
        objects += configs.map { .xcBuildConfiguration($0) }
        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, target.name), buildConfigurations: configs.referenceSet, defaultConfigurationName: "")
        objects.append(.xcConfigurationList(buildConfigList))

        var dependancies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFiles: [String] = []
        var extensions: [String] = []

        for dependancy in target.dependencies {
            switch dependancy {
            case let .target(dependencyTargetName):
                guard let dependencyTarget = spec.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetProxy = PBXContainerItemProxy(reference: generateUUID(PBXContainerItemProxy.self, target.name), containerPortal: projectReference, remoteGlobalIDString: targetNativeReferences[dependencyTargetName]!, proxyType: .nativeTarget, remoteInfo: dependencyTargetName)
                let targetDependancy = PBXTargetDependency(reference: generateUUID(PBXTargetDependency.self, dependencyTargetName + target.name), target: targetNativeReferences[dependencyTargetName]!, targetProxy: targetProxy.reference)

                objects.append(.pbxContainerItemProxy(targetProxy))
                objects.append(.pbxTargetDependency(targetDependancy))
                dependancies.append(targetDependancy.reference)

                let dependencyBuildFile = targetBuildFileReferences[dependencyTargetName]!
                // link
                targetFrameworkBuildFiles.append(dependencyBuildFile)

                if target.type.isApp {
                    if dependencyTarget.type.isExtension {
                        // embed app extensions
                        let embedSettings: [String: Any] = ["ATTRIBUTES": ["RemoveHeadersOnCopy"]]
                        let embedFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, dependencyFileReference + target.name), fileRef: dependencyFileReference, settings: embedSettings)
                        objects.append(.pbxBuildFile(embedFile))
                        extensions.append(embedFile.reference)
                    } else {
                        // embed frameworks
                        let embedSettings: [String: Any] = ["ATTRIBUTES": ["CodeSignOnCopy", "RemoveHeadersOnCopy"]]
                        let embedFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, dependencyFileReference + target.name), fileRef: dependencyFileReference, settings: embedSettings)
                        objects.append(.pbxBuildFile(embedFile))
                        copyFiles.append(embedFile.reference)
                    }
                }

            case let .framework(framework):
                let fileReference = getFileReference(path: Path(framework), inPath: basePath)
                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
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
                var platformName = target.platform.rawValue
                if target.platform == .macOS {
                    platformName = "Mac"
                }
                var platformPath = carthagePath + platformName
                var frameworkPath = platformPath + carthage
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                objects.append(.pbxBuildFile(buildFile))
                carthageFrameworksByPlatform[target.platform.rawValue]?.append(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> Set<String> {
            let files = sourceFilePaths.filter { getBuildPhaseForPath($0) == buildPhase }.map(generateSourceFile)
            return Set(files.map { $0.buildFile.reference })
        }

        func getRunScript(runScript: RunScript) throws -> PBXShellScriptBuildPhase {

            let shellScript: String
            switch runScript.script {
            case let .path(path):
                shellScript = try (basePath + path).read()
            case let .script(script):
                shellScript = script
            }
            let shellScriptPhase = PBXShellScriptBuildPhase(
                reference: generateUUID(PBXShellScriptBuildPhase.self, String(describing: runScript.name) + shellScript + target.name),
                files: [],
                name: runScript.name ?? "Run Script",
                inputPaths: Set(runScript.inputFiles),
                outputPaths: Set(runScript.outputFiles),
                shellPath: runScript.shell ?? "/bin/sh",
                shellScript: shellScript)
            shellScriptPhase.runOnlyForDeploymentPostprocessing = runScript.runOnlyWhenInstalling ? 1 : 0
            objects.append(.pbxShellScriptBuildPhase(shellScriptPhase))
            buildPhases.append(shellScriptPhase.reference)
            return shellScriptPhase
        }

        _ = try target.prebuildScripts.map(getRunScript)

        let sourcesBuildPhase = PBXSourcesBuildPhase(reference: generateUUID(PBXSourcesBuildPhase.self, target.name), files: getBuildFilesForPhase(.sources))
        objects.append(.pbxSourcesBuildPhase(sourcesBuildPhase))
        buildPhases.append(sourcesBuildPhase.reference)

        let resourcesBuildPhase = PBXResourcesBuildPhase(reference: generateUUID(PBXResourcesBuildPhase.self, target.name), files: getBuildFilesForPhase(.resources))
        objects.append(.pbxResourcesBuildPhase(resourcesBuildPhase))
        buildPhases.append(resourcesBuildPhase.reference)

        let headersBuildPhase = PBXHeadersBuildPhase(reference: generateUUID(PBXHeadersBuildPhase.self, target.name), files: getBuildFilesForPhase(.headers))
        objects.append(.pbxHeadersBuildPhase(headersBuildPhase))
        buildPhases.append(headersBuildPhase.reference)

        if !targetFrameworkBuildFiles.isEmpty {

            let frameworkBuildPhase = PBXFrameworksBuildPhase(
                reference: generateUUID(PBXFrameworksBuildPhase.self, target.name),
                files: Set(targetFrameworkBuildFiles),
                runOnlyForDeploymentPostprocessing: 0)

            objects.append(.pbxFrameworksBuildPhase(frameworkBuildPhase))
            buildPhases.append(frameworkBuildPhase.reference)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed app extensions" + target.name),
                dstPath: "",
                dstSubfolderSpec: .plugins,
                files: Set(extensions))

            objects.append(.pbxCopyFilesBuildPhase(copyFilesPhase))
            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyFiles.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed frameworks" + target.name),
                dstPath: "",
                dstSubfolderSpec: .frameworks,
                files: Set(copyFiles))

            objects.append(.pbxCopyFilesBuildPhase(copyFilesPhase))
            buildPhases.append(copyFilesPhase.reference)
        }

        if target.type.isApp {
            func getCarthageFrameworks(target: Target) -> [String] {
                var frameworks: [String] = []
                for dependency in target.dependencies {
                    switch dependency {
                    case let .carthage(framework): frameworks.append(framework)
                    case let .target(targetName):
                        if let target = spec.targets.first(where: { $0.name == targetName }) {
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
                let carthageScript = PBXShellScriptBuildPhase(reference: generateUUID(PBXShellScriptBuildPhase.self, "Carthage" + target.name), files: [], name: "Carthage", inputPaths: Set(inputPaths), outputPaths: [], shellPath: "/bin/sh", shellScript: "/usr/local/bin/carthage copy-frameworks\n")
                objects.append(.pbxShellScriptBuildPhase(carthageScript))
                buildPhases.append(carthageScript.reference)
            }
        }

        _ = try target.postbuildScripts.map(getRunScript)

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

    func getFileReference(path: Path, inPath: Path) -> String {
        if let fileReference = fileReferencesByPath[path] {
            return fileReference
        } else {
            let fileReference = PBXFileReference(reference: generateUUID(PBXFileReference.self, path.lastComponent), sourceTree: .group, path: path.byRemovingBase(path: inPath).string)
            objects.append(.pbxFileReference(fileReference))
            fileReferencesByPath[path] = fileReference.reference
            return fileReference.reference
        }
    }

    func getGroups(path: Path, depth: Int = 0) throws -> (filePaths: [Path], groups: [PBXGroup]) {

        let excludedFiles: [String] = [".DS_Store"]
        let directories = try path.children().filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }
        var filePaths = try path.children().filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }.filter { !excludedFiles.contains($0.lastComponent) }
        let localisedDirectories = try path.children().filter { $0.extension == "lproj" }
        var groupChildren: [String] = []
        var allFilePaths: [Path] = filePaths
        var groups: [PBXGroup] = []

        for path in directories {
            let subGroups = try getGroups(path: path, depth: depth + 1)
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
                let fileReference = PBXFileReference(reference: generateUUID(PBXFileReference.self, localisedDirectory.lastComponent), sourceTree: .group, name: localisedDirectory.lastComponentWithoutExtension, path: filePath)
                objects.append(.pbxFileReference(fileReference))

                let variantGroup = PBXVariantGroup(reference: generateUUID(PBXVariantGroup.self, path.lastComponent), children: Set([fileReference.reference]), name: path.lastComponent, sourceTree: .group)
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
            group = PBXGroup(reference: generateUUID(PBXGroup.self, path.lastComponent), children: groupChildren, sourceTree: .group, name: path.lastComponent, path: groupPath)
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
