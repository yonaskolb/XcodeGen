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
import xcproj
import JSONUtilities
import Yams
import ProjectSpec

public class PBXProjGenerator {

    let spec: ProjectSpec
    let basePath: Path
    let currentXcodeVersion: String

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

    public init(spec: ProjectSpec, path: Path, currentXcodeVersion: String) {
        self.currentXcodeVersion = currentXcodeVersion
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
        project.addObject(object)
    }

    public func generate() throws -> PBXProj {
        uuids = []
        project = PBXProj(archiveVersion: 1, objectVersion: 46, rootObject: generateUUID(PBXProject.self, spec.name))

        for group in spec.fileGroups {
            _ = try getGroups(path: basePath + group)
        }

        let buildConfigs: [XCBuildConfiguration] = spec.configs.map { config in
            let buildSettings = spec.getProjectBuildSettings(config: config)
            var baseConfigurationReference: String?
            if let configPath = spec.configFiles[config.name] {
                baseConfigurationReference = getFileReference(path: basePath + configPath, inPath: basePath)
            }
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }

        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, spec.name), buildConfigurations: buildConfigs.references, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

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
            let carthageGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Carthage"), children: platforms.references, sourceTree: .group, name: "Carthage", path: carthageBuildPath)
            addObject(carthageGroup)
            frameworkFiles.append(carthageGroup.reference)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(reference: generateUUID(PBXGroup.self, "Frameworks"), children: frameworkFiles, sourceTree: .group, name: "Frameworks")
            addObject(group)
            topLevelGroups.append(group)
        }

        let mainGroup = PBXGroup(reference: generateUUID(PBXGroup.self, "Project"), children: topLevelGroups.references, sourceTree: .group)
        addObject(mainGroup)

        let knownRegions: [String] = ["en", "Base"]
        let projectAttributes: [String: Any] = ["LastUpgradeCheck": currentXcodeVersion].merged(spec.attributes)
        let root = PBXProject(reference: project.rootObject,
                              buildConfigurationList: buildConfigList.reference,
                              compatibilityVersion: "Xcode 3.2",
                              mainGroup: mainGroup.reference,
                              developmentRegion: "English",
                              knownRegions: knownRegions,
                              targets: targets.references,
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

        let carthageDependencies = getAllCarthageDependencies(target: target)

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
            if let plistPath = infoPlists.first,
                !spec.targetHasBuildSetting("INFOPLIST_FILE", basePath: basePath, target: target, config: config) {
                buildSettings["INFOPLIST_FILE"] = plistPath.byRemovingBase(path: basePath)
            }

            // automatically calculate bundle id
            if let bundleIdPrefix = spec.options.bundleIdPrefix,
                !spec.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", basePath: basePath, target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name.replacingOccurrences(of: "_", with: "-").components(separatedBy: characterSet).joined(separator: "")
                buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleIdPrefix + "." + escapedTargetName
            }

            // automatically set test target name
            if target.type == .uiTestBundle,
                !spec.targetHasBuildSetting("TEST_TARGET_NAME", basePath: basePath, target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                        let dependencyTarget = spec.getTarget(dependency.reference),
                        dependencyTarget.type == .application {
                        buildSettings["TEST_TARGET_NAME"] = dependencyTarget.name
                        break
                    }
                }
            }

            // set Carthage search paths
            if !carthageDependencies.isEmpty {
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
                baseConfigurationReference = getFileReference(path: basePath + configPath, inPath: basePath)
            }
            return XCBuildConfiguration(reference: generateUUID(XCBuildConfiguration.self, config.name + target.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }
        configs.forEach(addObject)
        let buildConfigList = XCConfigurationList(reference: generateUUID(XCConfigurationList.self, target.name), buildConfigurations: configs.references, defaultConfigurationName: "")
        addObject(buildConfigList)

        var dependencies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFiles: [String] = []
        var extensions: [String] = []

        for dependency in target.dependencies {

            let embed = dependency.embed ?? (target.type.isApp ? true : false)
            switch dependency.type {
            case .target:
                let dependencyTargetName = dependency.reference
                guard let dependencyTarget = spec.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetProxy = PBXContainerItemProxy(reference: generateUUID(PBXContainerItemProxy.self, target.name), containerPortal: project.rootObject, remoteGlobalIDString: targetNativeReferences[dependencyTargetName]!, proxyType: .nativeTarget, remoteInfo: dependencyTargetName)
                let targetDependency = PBXTargetDependency(reference: generateUUID(PBXTargetDependency.self, dependencyTargetName + target.name), target: targetNativeReferences[dependencyTargetName]!, targetProxy: targetProxy.reference)

                addObject(targetProxy)
                addObject(targetDependency)
                dependencies.append(targetDependency.reference)

                // don't bother linking a target dependency
                // let dependencyBuildFile = targetBuildFileReferences[dependencyTargetName]!
                // targetFrameworkBuildFiles.append(dependencyBuildFile)

                if embed {
                    let embedSettings = dependency.buildSettings
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

                let fileReference = getFileReference(path: Path(dependency.reference), inPath: basePath)

                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)

                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference, settings: dependency.buildSettings)
                    addObject(embedFile)
                    copyFiles.append(embedFile.reference)
                }
            case .carthage:
                if carthageFrameworksByPlatform[target.platform.carthageDirectoryName] == nil {
                    carthageFrameworksByPlatform[target.platform.carthageDirectoryName] = []
                }
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependency.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(reference: generateUUID(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)
                carthageFrameworksByPlatform[target.platform.carthageDirectoryName]?.append(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [String] {
            let files = sourceFilePaths.filter { getBuildPhaseForPath($0) == buildPhase }.map(generateSourceFile)
            return files.map { $0.buildFile.reference }
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
                inputPaths: buildScript.inputFiles,
                outputPaths: buildScript.outputFiles,
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
                files: targetFrameworkBuildFiles,
                runOnlyForDeploymentPostprocessing: 0)

            addObject(frameworkBuildPhase)
            buildPhases.append(frameworkBuildPhase.reference)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed app extensions" + target.name),
                dstPath: "",
                dstSubfolderSpec: .plugins,
                files: extensions)

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyFiles.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: generateUUID(PBXCopyFilesBuildPhase.self, "embed frameworks" + target.name),
                dstPath: "",
                dstSubfolderSpec: .frameworks,
                files: copyFiles)

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        let carthageFrameworksToEmbed = Array(Set(carthageDependencies
            .filter { $0.embed ?? true }
            .map { $0.reference }))
            .sorted()

        if !carthageFrameworksToEmbed.isEmpty {

            if target.type.isApp && target.platform != .macOS {
                let inputPaths = carthageFrameworksToEmbed.map { "$(SRCROOT)/\(carthageBuildPath)/\(target.platform)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let outputPaths = carthageFrameworksToEmbed.map { "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let carthageScript = PBXShellScriptBuildPhase(reference: generateUUID(PBXShellScriptBuildPhase.self, "Carthage" + target.name), files: [], name: "Carthage", inputPaths: inputPaths, outputPaths: outputPaths, shellPath: "/bin/sh", shellScript: "/usr/local/bin/carthage copy-frameworks\n")
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
            dependencies: dependencies,
            name: target.name,
            productReference: fileReference,
            productType: target.type)
        addObject(nativeTarget)
        return nativeTarget
    }

    func getCarthageBuildPath(platform: Platform) -> String {

        let carthagePath = Path(carthageBuildPath)
        let platformName = platform.carthageDirectoryName
        return "\(carthagePath)/\(platformName)"
    }

    func getAllCarthageDependencies(target: Target) -> [Dependency] {
        var frameworks: [Dependency] = []
        for dependency in target.dependencies {
            switch dependency.type {
            case .carthage:
                frameworks.append(dependency)
            case .target:
                if let target = spec.getTarget(dependency.reference) {
                    frameworks += getAllCarthageDependencies(target: target)
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

        let directories = try path.children()
            .filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }
            .sorted { $0.lastComponent < $1.lastComponent }

        let filePaths = try path.children()
            .filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }
            .filter { !excludedFiles.contains($0.lastComponent) }
            .sorted { $0.lastComponent < $1.lastComponent }

        let localisedDirectories = try path.children()
            .filter { $0.extension == "lproj" }
            .sorted { $0.lastComponent < $1.lastComponent }

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
            for path in try localisedDirectory.children().sorted { $0.lastComponent < $1.lastComponent } {
                let filePath = "\(localisedDirectory.lastComponent)/\(path.lastComponent)"
                let fileReference = PBXFileReference(reference: generateUUID(PBXFileReference.self, localisedDirectory.lastComponent), sourceTree: .group, name: localisedDirectory.lastComponentWithoutExtension, path: filePath)
                addObject(fileReference)

                let variantGroup = PBXVariantGroup(reference: generateUUID(PBXVariantGroup.self, path.lastComponent), children: [fileReference.reference], name: path.lastComponent, sourceTree: .group)
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
