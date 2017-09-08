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
    let currentXcodeVersion = "0830"

    var fileReferencesByPath: [Path: String] = [:]
    var groupsByPath: [Path: PBXGroup] = [:]

    var targetNativeReferences: [String: String] = [:]
    var targetBuildFileReferences: [String: String] = [:]
    var targetFileReferences: [String: String] = [:]
    var topLevelGroups: [PBXGroup] = []
    var carthageFrameworksByPlatform: [String: [String]] = [:]
    var frameworkFiles: [String] = []

    var uuids: Set<String> = []
    var project: PBXProj!

    var carthageBuildPath: String {
        return spec.options.carthageBuildPath ?? "Carthage/Build"
    }

    public init(spec: ProjectSpec, path: Path) {
        self.spec = spec
        basePath = path
    }

    public func generateUUID<T: PBXObject>(_ element: T.Type, _ id: String) -> String {
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

    func addObject(_ object: PBXObject) {
        switch object {
        case let object as PBXBuildFile: project.buildFiles.append(object)
        case let object as PBXAggregateTarget: project.aggregateTargets.append(object)
        case let object as PBXContainerItemProxy: project.containerItemProxies.append(object)
        case let object as PBXCopyFilesBuildPhase: project.copyFilesBuildPhases.append(object)
        case let object as PBXGroup: project.groups.append(object)
        case let object as PBXFileElement: project.fileElements.append(object)
        case let object as XCConfigurationList: project.configurationLists.append(object)
        case let object as XCBuildConfiguration: project.buildConfigurations.append(object)
        case let object as PBXVariantGroup: project.variantGroups.append(object)
        case let object as PBXTargetDependency: project.targetDependencies.append(object)
        case let object as PBXSourcesBuildPhase: project.sourcesBuildPhases.append(object)
        case let object as PBXShellScriptBuildPhase: project.shellScriptBuildPhases.append(object)
        case let object as PBXResourcesBuildPhase: project.resourcesBuildPhases.append(object)
        case let object as PBXFrameworksBuildPhase: project.frameworksBuildPhases.append(object)
        case let object as PBXHeadersBuildPhase: project.headersBuildPhases.append(object)
        case let object as PBXNativeTarget: project.nativeTargets.append(object)
        case let object as PBXFileReference: project.fileReferences.append(object)
        case let object as PBXProject: project.projects.append(object)
        default: break
        }
    }

    public func generate() throws -> PBXProj {
        uuids = []
        project = PBXProj(archiveVersion: 1, objectVersion: 46, rootObject: generateUUID(PBXProject.self, spec.name))

        let buildConfigs: [XCBuildConfiguration] = spec.configs.map { config in
            let buildSettings = spec.getProjectBuildSettings(config: config)
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name), name: config.name, baseConfigurationReference: nil, buildSettings: buildSettings)
        }

        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, spec.name), buildConfigurations: buildConfigs.referenceSet, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

        buildConfigs.forEach(addObject)
        addObject(buildConfigList)

        for target in spec.targets {
            targetNativeReferences[target.name] = generateUUID(PBXNativeTarget.self, target.name)

            let fileReference = PBXFileReference(reference: generateUUID(PBXFileReference.self, target.name), sourceTree: .buildProductsDir, explicitFileType: target.type.fileExtension, path: target.filename, includeInIndex: 0)
            addObject(fileReference)
            targetFileReferences[target.name] = fileReference.reference

            let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference.reference), fileRef: fileReference.reference)
            addObject(buildFile)
            targetBuildFileReferences[target.name] = buildFile.reference
        }

        let targets = try spec.targets.map(generateTarget)

        let productGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Products"), children: Array(targetFileReferences.values), sourceTree: .group, name: "Products")
        addObject(productGroup)
        topLevelGroups.append(productGroup)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup = PBXGroup(reference: generateUUID(PBXGroup.self, platform), children: fileReferences, sourceTree: .group, name: platform, path: platform)
                addObject(platformGroup)
                platforms.append(platformGroup)
            }
            let carthageGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Carthage"), children: platforms.referenceList, sourceTree: .group, name: "Carthage", path: carthageBuildPath)
            addObject(carthageGroup)
            frameworkFiles.append(carthageGroup.reference)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(reference: generateUUID(PBXGroup.self, "Frameworks"), children: frameworkFiles, sourceTree: .group, name: "Frameworks")
            addObject(group)
            topLevelGroups.append(group)
        }

        let mainGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Project"), children: topLevelGroups.referenceList, sourceTree: .group)
        addObject(mainGroup)

        let knownRegions: [String] = ["en", "Base"]
        let projectAttributes: [String: Any] = spec.attributes.isEmpty ? ["LastUpgradeCheck": currentXcodeVersion] : spec.attributes
        let root = PBXProject(reference: project.rootObject,
                              buildConfigurationList: buildConfigList.reference,
                              compatibilityVersion: "Xcode 3.2",
                              mainGroup: mainGroup.reference,
                              developmentRegion: "English",
                              knownRegions: knownRegions,
                              targets: targets.referenceList,
                              attributes: projectAttributes)
        project.projects.append(root)

        return project
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
        addObject(buildFile)
        return SourceFile(path: path, fileReference: fileReference, buildFile: buildFile)
    }

    func generateTarget(_ target: Target) throws -> PBXNativeTarget {

        let carthageFrameworks = Set(getCarthageFrameworks(target: target))

        let sourcePaths = target.sources.map { basePath + $0 }
        var sourceFilePaths: [Path] = []

        for source in sourcePaths {
            let sourceGroups = try getGroups(path: source)
            sourceFilePaths += sourceGroups.filePaths
        }

        // find all Info.plist
        let infoPlists: [Path] = sourcePaths.reduce([]) {
            $0 + ((try? $1.recursiveChildren()) ?? []).filter { $0.lastComponent == "Info.plist" }
        }

        let configs: [XCBuildConfiguration] = spec.configs.map { config in
            var buildSettings = spec.getTargetBuildSettings(target: target, config: config)

            // automatically set INFOPLIST_FILE path
            if buildSettings["INFOPLIST_FILE"] == nil {
                if let plistPath = infoPlists.first {
                    buildSettings["INFOPLIST_FILE"] = plistPath.byRemovingBase(path: basePath)
                }
            }

            // set Carthage search paths
            if !carthageFrameworks.isEmpty {
                let frameworkSearchPaths = "FRAMEWORK_SEARCH_PATHS"
                let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + getCarthageBuildPath(platform: target.platform)
                var newSettings: [String] = []
                if var array = buildSettings[frameworkSearchPaths] as? [String] {
                    array.append(carthagePlatformBuildPath)
                    buildSettings[frameworkSearchPaths] = array
                } else if let string = buildSettings[frameworkSearchPaths] as? String {
                    buildSettings[frameworkSearchPaths] = [string, carthagePlatformBuildPath]
                } else {
                    buildSettings[frameworkSearchPaths] = ["$(inherited)", carthagePlatformBuildPath]
                }
            }

            var baseConfigurationReference: String?
            if let configPath = target.configFiles[config.name] {
                let path = basePath + configPath
                baseConfigurationReference = fileReferencesByPath[path]
            }
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name + target.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }
        configs.forEach(addObject)
        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, target.name), buildConfigurations: configs.referenceSet, defaultConfigurationName: "")
        addObject(buildConfigList)

        var dependancies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFiles: [String] = []
        var extensions: [String] = []

        for dependancy in target.dependencies {

            let embed = dependancy.embed ?? (target.type.isApp ? true : false)
            switch dependancy.type {
            case .target:
                let dependencyTargetName = dependancy.reference
                guard let dependencyTarget = spec.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetProxy = PBXContainerItemProxy(reference: generateUUID(PBXContainerItemProxy.self, target.name), containerPortal: project.rootObject, remoteGlobalIDString: targetNativeReferences[dependencyTargetName]!, proxyType: .nativeTarget, remoteInfo: dependencyTargetName)
                let targetDependancy = PBXTargetDependency(reference: generateUUID(PBXTargetDependency.self, dependencyTargetName + target.name), target: targetNativeReferences[dependencyTargetName]!, targetProxy: targetProxy.reference)

                addObject(targetProxy)
                addObject(targetDependancy)
                dependancies.append(targetDependancy.reference)

                // don't bother linking a target dependency
                // let dependencyBuildFile = targetBuildFileReferences[dependencyTargetName]!
                // targetFrameworkBuildFiles.append(dependencyBuildFile)

                if embed {
                    let embedSettings = dependancy.buildSettings
                    let embedFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, dependencyFileReference + target.name), fileRef: dependencyFileReference, settings: embedSettings)
                    addObject(embedFile)

                    if dependencyTarget.type.isExtension {
                        // embed app extension
                        extensions.append(embedFile.reference)
                    } else {
                        copyFiles.append(embedFile.reference)
                    }
                }

            case .framework:

                let fileReference = getFileReference(path: Path(dependancy.reference), inPath: basePath)

                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)

                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference, settings: dependancy.buildSettings)
                    addObject(embedFile)
                    copyFiles.append(embedFile.reference)
                }
            case .carthage:
                if carthageFrameworksByPlatform[target.platform.rawValue] == nil {
                    carthageFrameworksByPlatform[target.platform.rawValue] = []
                }
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependancy.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)
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

        func getBuildScript(buildScript: BuildScript) throws -> PBXShellScriptBuildPhase {

            var shellScript: String
            switch buildScript.script {
            case let .path(path):
                shellScript = try (basePath + path).read()
            case let .script(script):
                shellScript = script
            }
            shellScript = shellScript.replacingOccurrences(of: "\"", with: "\\\"") // TODO: remove when xcodeproj escaped values
            let shellScriptPhase = PBXShellScriptBuildPhase(
                reference: generateUUID(PBXShellScriptBuildPhase.self, String(describing: buildScript.name) + shellScript + target.name),
                files: [],
                name: buildScript.name ?? "Run Script",
                inputPaths: Set(buildScript.inputFiles),
                outputPaths: Set(buildScript.outputFiles),
                shellPath: buildScript.shell ?? "/bin/sh",
                shellScript: shellScript)
            shellScriptPhase.runOnlyForDeploymentPostprocessing = buildScript.runOnlyWhenInstalling ? 1 : 0
            addObject(shellScriptPhase)
            buildPhases.append(shellScriptPhase.reference)
            return shellScriptPhase
        }

        _ = try target.prebuildScripts.map(getBuildScript)

        let sourcesBuildPhase = PBXSourcesBuildPhase(reference: generateUUID(PBXSourcesBuildPhase.self, target.name), files: getBuildFilesForPhase(.sources))
        addObject(sourcesBuildPhase)
        buildPhases.append(sourcesBuildPhase.reference)

        let resourcesBuildPhase = PBXResourcesBuildPhase(reference: generateUUID(PBXResourcesBuildPhase.self, target.name), files: getBuildFilesForPhase(.resources))
        addObject(resourcesBuildPhase)
        buildPhases.append(resourcesBuildPhase.reference)

        let headersBuildPhase = PBXHeadersBuildPhase(reference: generateUUID(PBXHeadersBuildPhase.self, target.name), files: getBuildFilesForPhase(.headers))
        addObject(headersBuildPhase)
        buildPhases.append(headersBuildPhase.reference)

        if !targetFrameworkBuildFiles.isEmpty {

            let frameworkBuildPhase = PBXFrameworksBuildPhase(
                reference: generateUUID(PBXFrameworksBuildPhase.self, target.name),
                files: Set(targetFrameworkBuildFiles),
                runOnlyForDeploymentPostprocessing: 0)

            addObject(frameworkBuildPhase)
            buildPhases.append(frameworkBuildPhase.reference)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed app extensions" + target.name),
                dstPath: "",
                dstSubfolderSpec: .plugins,
                files: Set(extensions))

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyFiles.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed frameworks" + target.name),
                dstPath: "",
                dstSubfolderSpec: .frameworks,
                files: Set(copyFiles))

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        if !carthageFrameworks.isEmpty {

            if target.type.isApp {
                let inputPaths = carthageFrameworks.map { "$(SRCROOT)/\(carthageBuildPath)/\(target.platform)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let carthageScript = PBXShellScriptBuildPhase(reference: generateUUID(PBXShellScriptBuildPhase.self, "Carthage" + target.name), files: [], name: "Carthage", inputPaths: Set(inputPaths), outputPaths: [], shellPath: "/bin/sh", shellScript: "/usr/local/bin/carthage copy-frameworks\n")
                addObject(carthageScript)
                buildPhases.append(carthageScript.reference)
            }
        }

        _ = try target.postbuildScripts.map(getBuildScript)

        let nativeTarget = PBXNativeTarget(
            reference: targetNativeReferences[target.name]!,
            buildConfigurationList: buildConfigList.reference,
            buildPhases: buildPhases,
            buildRules: [],
            dependencies: dependancies,
            name: target.name,
            productReference: fileReference,
            productType: target.type)
        addObject(nativeTarget)
        return nativeTarget
    }

    func getCarthageBuildPath(platform: Platform) -> String {

        let carthagePath = Path(carthageBuildPath)
        var platformName = platform.rawValue
        if platform == .macOS {
            platformName = "Mac"
        }
        return "\(carthagePath)/\(platformName)"
    }

    func getCarthageFrameworks(target: Target) -> [String] {
        var frameworks: [String] = []
        for dependency in target.dependencies {
            switch dependency.type {
            case .carthage: frameworks.append(dependency.reference)
            case .target:
                if let target = spec.getTarget(dependency.reference) {
                    frameworks += getCarthageFrameworks(target: target)
                }
            default: break
            }
        }
        return frameworks
    }

    func getBuildPhaseForPath(_ path: Path) -> BuildPhase? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "swift", "m", "cpp": return .sources
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
            addObject(fileReference)
            fileReferencesByPath[path] = fileReference.reference
            return fileReference.reference
        }
    }

    func getGroups(path: Path, depth: Int = 0) throws -> (filePaths: [Path], groups: [PBXGroup]) {

        let excludedFiles: [String] = [".DS_Store"]
        let directories = try path.children().filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }
        let filePaths = try path.children().filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }.filter { !excludedFiles.contains($0.lastComponent) }
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
                addObject(fileReference)

                let variantGroup = PBXVariantGroup(reference: generateUUID(PBXVariantGroup.self, path.lastComponent), children: Set([fileReference.reference]), name: path.lastComponent, sourceTree: .group)
                addObject(variantGroup)

                fileReferencesByPath[path] = variantGroup.reference
                groupChildren.append(variantGroup.reference)
                allFilePaths.append(path)
            }
        }

        let groupPath: String = depth == 0 ? path.byRemovingBase(path: basePath).string : path.lastComponent
        let group: PBXGroup
        if let cachedGroup = groupsByPath[path] {
            group = cachedGroup
        } else {
            group = PBXGroup(reference: generateUUID(PBXGroup.self, path.lastComponent), children: groupChildren, sourceTree: .group, name: path.lastComponent, path: groupPath)
            addObject(group)
            if depth == 0 {
                topLevelGroups.append(group)
            }
            groupsByPath[path] = group
        }
        groups.insert(group, at: 0)
        return (allFilePaths, groups)
    }
}
