import Foundation
import PathKit
import xcproj
import JSONUtilities
import Yams
import ProjectSpec

public class PBXProjGenerator {

    let spec: ProjectSpec

    let proj: PBXProj
    let sourceGenerator: SourceGenerator
    let referenceGenerator = ReferenceGenerator()

    var targetNativeReferences: [String: String] = [:]
    var targetBuildFiles: [String: PBXBuildFile] = [:]
    var targetFileReferences: [String: String] = [:]
    var topLevelGroups: Set<String> = []
    var carthageFrameworksByPlatform: [String: Set<String>] = [:]
    var frameworkFiles: [String] = []

    var generated = false

    var carthageBuildPath: String {
        return spec.options.carthageBuildPath ?? "Carthage/Build"
    }

    public init(spec: ProjectSpec) {
        self.spec = spec
        proj = PBXProj(objectVersion: 46, rootObject: referenceGenerator.generate(PBXProject.self, spec.name))
        sourceGenerator = SourceGenerator(spec: spec, referenceGenerator: referenceGenerator) { _ in }
        sourceGenerator.addObject = { [weak self] object in
            self?.addObject(object)
        }
    }

    func addObject(_ object: PBXObject) {
        proj.objects.addObject(object)
    }

    public func generate() throws -> PBXProj {
        if generated {
            fatalError("Cannot use PBXProjGenerator to generate more than once")
        }
        generated = true
        for group in spec.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let buildConfigs: [XCBuildConfiguration] = spec.configs.map { config in
            let buildSettings = spec.getProjectBuildSettings(config: config)
            var baseConfigurationReference: String?
            if let configPath = spec.configFiles[config.name] {
                baseConfigurationReference = sourceGenerator.getContainedFileReference(path: spec.basePath + configPath)
            }
            return XCBuildConfiguration(reference: referenceGenerator.generate(XCBuildConfiguration.self, config.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }

        let buildConfigList = XCConfigurationList(reference: referenceGenerator.generate(XCConfigurationList.self, spec.name), buildConfigurations: buildConfigs.references, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

        buildConfigs.forEach(addObject)
        addObject(buildConfigList)

        for target in spec.targets {
            targetNativeReferences[target.name] =
                referenceGenerator.generate(
                    target.isLegacy ? PBXLegacyTarget.self : PBXNativeTarget.self, target.name)

            let fileReference = PBXFileReference(reference: referenceGenerator.generate(PBXFileReference.self, target.name), sourceTree: .buildProductsDir, explicitFileType: target.type.fileExtension, path: target.filename, includeInIndex: 0)
            addObject(fileReference)
            targetFileReferences[target.name] = fileReference.reference

            let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference.reference), fileRef: fileReference.reference)
            addObject(buildFile)
            targetBuildFiles[target.name] = buildFile
        }

        let targets = try spec.targets.map(generateTarget)

        let productGroup = PBXGroup(reference: referenceGenerator.generate(PBXGroup.self, "Products"), children: Array(targetFileReferences.values), sourceTree: .group, name: "Products")
        addObject(productGroup)
        topLevelGroups.insert(productGroup.reference)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup = PBXGroup(reference: referenceGenerator.generate(PBXGroup.self, "Carthage" + platform), children: fileReferences.sorted(), sourceTree: .group, name: platform, path: platform)
                addObject(platformGroup)
                platforms.append(platformGroup)
            }
            let carthageGroup = PBXGroup(reference: referenceGenerator.generate(PBXGroup.self, "Carthage"), children: platforms.references.sorted(), sourceTree: .group, name: "Carthage", path: carthageBuildPath)
            addObject(carthageGroup)
            frameworkFiles.append(carthageGroup.reference)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(reference: referenceGenerator.generate(PBXGroup.self, "Frameworks"), children: frameworkFiles, sourceTree: .group, name: "Frameworks")
            addObject(group)
            topLevelGroups.insert(group.reference)
        }

        for rootGroup in sourceGenerator.rootGroups {
            topLevelGroups.insert(rootGroup)
        }

        let mainGroup = PBXGroup(reference: referenceGenerator.generate(PBXGroup.self, "Project"), children: Array(topLevelGroups), sourceTree: .group, usesTabs: spec.options.usesTabs.map{ $0 ? 1 : 0 }, indentWidth: spec.options.indentWidth, tabWidth: spec.options.tabWidth)
        addObject(mainGroup)

        sortGroups(group: mainGroup)

        let projectAttributes: [String: Any] = ["LastUpgradeCheck": spec.xcodeVersion].merged(spec.attributes)
        let root = PBXProject(name: spec.name,
                              reference: proj.rootObject,
                              buildConfigurationList: buildConfigList.reference,
                              compatibilityVersion: "Xcode 3.2",
                              mainGroup: mainGroup.reference,
                              developmentRegion: spec.options.developmentLanguage ?? "en",
                              knownRegions: sourceGenerator.knownRegions.sorted(),
                              targets: targets.references,
                              attributes: projectAttributes)
        proj.objects.projects.append(root)

        return proj
    }

    func sortGroups(group: PBXGroup) {
        // sort children
        let children = group.children
            .flatMap { proj.objects.getFileElement(reference: $0) }
            .sorted { child1, child2 in
                if child1.sortOrder == child2.sortOrder {
                    return child1.nameOrPath < child2.nameOrPath
                } else {
                    return child1.sortOrder < child2.sortOrder
                }
            }
        group.children = children.map { $0.reference }.filter { $0 != group.reference }

        // sort sub groups
        let childGroups = group.children.flatMap { proj.objects.groups[$0] }
        childGroups.forEach(sortGroups)
    }
    
    func generateTarget(_ target: Target) throws -> PBXTarget {

        sourceGenerator.targetName = target.name
        let carthageDependencies = getAllCarthageDependencies(target: target)

        let sourceFiles = try sourceGenerator.getAllSourceFiles(sources: target.sources)

        // find all Info.plist files
        let infoPlists: [Path] = target.sources.map { spec.basePath + $0.path }.flatMap { (path) -> [Path] in
            if path.isFile {
                if path.lastComponent == "Info.plist" {
                    return [path]
                }
            } else {
                if let children = try? path.recursiveChildren() {
                    return children.filter { $0.lastComponent == "Info.plist" }
                }
            }
            return []
        }

        let configs: [XCBuildConfiguration] = spec.configs.map { config in
            var buildSettings = spec.getTargetBuildSettings(target: target, config: config)

            // automatically set INFOPLIST_FILE path
            if let plistPath = infoPlists.first,
                !spec.targetHasBuildSetting("INFOPLIST_FILE", basePath: spec.basePath, target: target, config: config) {
                buildSettings["INFOPLIST_FILE"] = plistPath.byRemovingBase(path: spec.basePath)
            }

            // automatically calculate bundle id
            if let bundleIdPrefix = spec.options.bundleIdPrefix,
                !spec.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", basePath: spec.basePath, target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name.replacingOccurrences(of: "_", with: "-").components(separatedBy: characterSet).joined(separator: "")
                buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleIdPrefix + "." + escapedTargetName
            }

            // automatically set test target name
            if target.type == .uiTestBundle,
                !spec.targetHasBuildSetting("TEST_TARGET_NAME", basePath: spec.basePath, target: target, config: config) {
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
                baseConfigurationReference = sourceGenerator.getContainedFileReference(path: spec.basePath + configPath)
            }
            return XCBuildConfiguration(reference: referenceGenerator.generate(XCBuildConfiguration.self, config.name + target.name), name: config.name, baseConfigurationReference: baseConfigurationReference, buildSettings: buildSettings)
        }
        configs.forEach(addObject)
        let buildConfigList = XCConfigurationList(reference: referenceGenerator.generate(XCConfigurationList.self, target.name), buildConfigurations: configs.references, defaultConfigurationName: "")
        addObject(buildConfigList)

        var dependencies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFrameworksReferences: [String] = []
        var copyResourcesReferences: [String] = []
        var copyWatchReferences: [String] = []
        var extensions: [String] = []

        for dependency in target.dependencies {

            let embed = dependency.embed ?? (target.type.isApp ? true : false)
            switch dependency.type {
            case .target:
                let dependencyTargetName = dependency.reference
                guard let dependencyTarget = spec.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetProxy = PBXContainerItemProxy(reference: referenceGenerator.generate(PBXContainerItemProxy.self, target.name), containerPortal: proj.rootObject, remoteGlobalIDString: targetNativeReferences[dependencyTargetName]!, proxyType: .nativeTarget, remoteInfo: dependencyTargetName)
                let targetDependency = PBXTargetDependency(reference: referenceGenerator.generate(PBXTargetDependency.self, dependencyTargetName + target.name), target: targetNativeReferences[dependencyTargetName]!, targetProxy: targetProxy.reference)

                addObject(targetProxy)
                addObject(targetDependency)
                dependencies.append(targetDependency.reference)

                if (dependencyTarget.type.isLibrary || dependencyTarget.type.isFramework) && dependency.link {
                    let dependencyBuildFile = targetBuildFiles[dependencyTargetName]!
                    let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, dependencyBuildFile.reference + target.name), fileRef: dependencyBuildFile.fileRef!)
                    addObject(buildFile)
                    targetFrameworkBuildFiles.append(buildFile.reference)
                }

                if embed && !dependencyTarget.type.isLibrary {

                    let embedSettings = dependency.buildSettings
                    let embedFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, dependencyFileReference + target.name), fileRef: dependencyFileReference, settings: embedSettings)
                    addObject(embedFile)

                    if dependencyTarget.type.isExtension {
                        // embed app extension
                        extensions.append(embedFile.reference)
                    } else if dependencyTarget.type.isFramework {
                        copyFrameworksReferences.append(embedFile.reference)
                    } else if dependencyTarget.type.isApp && dependencyTarget.platform == .watchOS {
                        copyWatchReferences.append(embedFile.reference)
                    } else {
                        copyResourcesReferences.append(embedFile.reference)
                    }
                }

            case .framework:
                let fileReference: String
                if dependency.implicit {
                    fileReference = sourceGenerator.getFileReference(path: Path(dependency.reference), inPath: spec.basePath, sourceTree: .buildProductsDir)
                } else {
                    fileReference = sourceGenerator.getFileReference(path: Path(dependency.reference), inPath: spec.basePath)
                }

                let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)

                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference, settings: dependency.buildSettings)
                    addObject(embedFile)
                    copyFrameworksReferences.append(embedFile.reference)
                }
            case .carthage:
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependency.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference)
                addObject(buildFile)
                carthageFrameworksByPlatform[target.platform.carthageDirectoryName, default: []].insert(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
                if target.platform == .macOS && target.type.isApp {
                    let embedFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference + target.name), fileRef: fileReference, settings: dependency.buildSettings)
                    addObject(embedFile)
                    copyFrameworksReferences.append(embedFile.reference)
                }
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [String] {
            let files = sourceFiles
                .filter { $0.buildPhase == buildPhase }
                .sorted { $0.path.lastComponent < $1.path.lastComponent }
            files.forEach { addObject($0.buildFile) }
            return files.map { $0.buildFile.reference }
        }

        func getBuildScript(buildScript: BuildScript) throws -> PBXShellScriptBuildPhase {

            let shellScript: String
            switch buildScript.script {
            case let .path(path):
                shellScript = try (spec.basePath + path).read()
            case let .script(script):
                shellScript = script
            }

            let shellScriptPhase = PBXShellScriptBuildPhase(
                reference: referenceGenerator.generate(PBXShellScriptBuildPhase.self, String(describing: buildScript.name) + shellScript + target.name),
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

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        if !sourcesBuildPhaseFiles.isEmpty {
            let sourcesBuildPhase = PBXSourcesBuildPhase(reference: referenceGenerator.generate(PBXSourcesBuildPhase.self, target.name), files: sourcesBuildPhaseFiles)
            addObject(sourcesBuildPhase)
            buildPhases.append(sourcesBuildPhase.reference)
        }

        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources) + copyResourcesReferences
        if !resourcesBuildPhaseFiles.isEmpty {
            let resourcesBuildPhase = PBXResourcesBuildPhase(reference: referenceGenerator.generate(PBXResourcesBuildPhase.self, target.name), files: resourcesBuildPhaseFiles)
            addObject(resourcesBuildPhase)
            buildPhases.append(resourcesBuildPhase.reference)
        }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers)
        if !headersBuildPhaseFiles.isEmpty && (target.type == .framework || target.type == .dynamicLibrary) {
            let headersBuildPhase = PBXHeadersBuildPhase(reference: referenceGenerator.generate(PBXHeadersBuildPhase.self, target.name), files: headersBuildPhaseFiles)
            addObject(headersBuildPhase)
            buildPhases.append(headersBuildPhase.reference)
        }

        if !targetFrameworkBuildFiles.isEmpty {

            let frameworkBuildPhase = PBXFrameworksBuildPhase(
                reference: referenceGenerator.generate(PBXFrameworksBuildPhase.self, target.name),
                files: targetFrameworkBuildFiles,
                runOnlyForDeploymentPostprocessing: 0)

            addObject(frameworkBuildPhase)
            buildPhases.append(frameworkBuildPhase.reference)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: referenceGenerator.generate(PBXCopyFilesBuildPhase.self, "embed app extensions" + target.name),
                dstPath: "",
                dstSubfolderSpec: .plugins,
                files: extensions)

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyFrameworksReferences.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: referenceGenerator.generate(PBXCopyFilesBuildPhase.self, "embed frameworks" + target.name),
                dstPath: "",
                dstSubfolderSpec: .frameworks,
                files: copyFrameworksReferences)

            addObject(copyFilesPhase)
            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyWatchReferences.isEmpty {

            let copyFilesPhase = PBXCopyFilesBuildPhase(
                reference: referenceGenerator.generate(PBXCopyFilesBuildPhase.self, "embed watch content" + target.name),
                dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
                dstSubfolderSpec: .productsDirectory,
                files: copyWatchReferences)

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
                let carthageScript = PBXShellScriptBuildPhase(reference: referenceGenerator.generate(PBXShellScriptBuildPhase.self, "Carthage" + target.name), files: [], name: "Carthage", inputPaths: inputPaths, outputPaths: outputPaths, shellPath: "/bin/sh", shellScript: "/usr/local/bin/carthage copy-frameworks\n")
                addObject(carthageScript)
                buildPhases.append(carthageScript.reference)
            }
        }

        _ = try target.postbuildScripts.map(getBuildScript)

        let pbxtarget: PBXTarget
        if target.isLegacy {
            pbxtarget = PBXLegacyTarget(
                reference: targetNativeReferences[target.name]!,
                name: target.name,
                buildToolPath: target.legacy?.toolPath,
                buildArgumentsString: target.legacy?.arguments,
                passBuildSettingsInEnvironment: target.legacy?.passSettings ?? false,
                buildWorkingDirectory: target.legacy?.workingDirectory,
                buildConfigurationList: buildConfigList.reference,
                buildPhases: buildPhases,
                buildRules: [],
                dependencies: dependencies,
                productReference: fileReference,
                productType: nil
            )
        } else {
            pbxtarget = PBXNativeTarget(
                reference: targetNativeReferences[target.name]!,
                name: target.name,
                buildConfigurationList: buildConfigList.reference,
                buildPhases: buildPhases,
                buildRules: [],
                dependencies: dependencies,
                productReference: fileReference,
                productType: target.type)
        }
        addObject(pbxtarget)
        return pbxtarget
    }

    func getCarthageBuildPath(platform: Platform) -> String {

        let carthagePath = Path(carthageBuildPath)
        let platformName = platform.carthageDirectoryName
        return "\(carthagePath)/\(platformName)"
    }

    func getAllCarthageDependencies(target: Target, visitedTargets: [String: Bool] = [:]) -> [Dependency] {

        // this is used to resolve cyclical target dependencies
        var visitedTargets = visitedTargets
        visitedTargets[target.name] = true

        var frameworks: [Dependency] = []

        for dependency in target.dependencies {
            switch dependency.type {
            case .carthage:
                frameworks.append(dependency)
            case .target:
                let targetName = dependency.reference
                if visitedTargets[targetName] == true {
                    return []
                }
                if let target = spec.getTarget(targetName) {
                    frameworks += getAllCarthageDependencies(target: target, visitedTargets: visitedTargets)
                }
            default: break
            }
        }
        return frameworks
    }
}
