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
    var targetNativeReferences: [String: String] = [:]
    var targetBuildFiles: [String: (reference: String, buildFile: PBXBuildFile)] = [:]
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
        proj = PBXProj(objectVersion: 46, rootObject: "")
        sourceGenerator = SourceGenerator(spec: spec, generateReference: { self.proj.objects.generateReference($0, $1) }) { (_, _) in }
        sourceGenerator.addObject = { [weak self] (object, reference) in
            self?.addObject(object, reference: reference)
        }
    }

    func addObject(_ object: PBXObject, reference: String) {
        proj.objects.addObject(object, reference: reference)
    }

    public func generate() throws -> (reference: String, project: PBXProj) {
        if generated {
            fatalError("Cannot use PBXProjGenerator to generate more than once")
        }
        generated = true
        for group in spec.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let buildConfigs: [(reference: String, config: XCBuildConfiguration)] = spec.configs.map { config in
            let buildSettings = spec.getProjectBuildSettings(config: config)
            var baseConfigurationReference: String?
            if let configPath = spec.configFiles[config.name] {
                baseConfigurationReference = sourceGenerator.getContainedFileReference(path: spec.basePath + configPath)
            }
            let buildConfiguration = XCBuildConfiguration(
                name: config.name,
                baseConfigurationReference: baseConfigurationReference,
                buildSettings: buildSettings
            )
            let buildConfigurationReference = proj.objects.generateReference(buildConfiguration, config.name)
            return (reference: buildConfigurationReference, config: buildConfiguration)
        }

        let buildConfigList = XCConfigurationList(
            buildConfigurations: buildConfigs.map({$0.reference}),
            defaultConfigurationName: buildConfigs.first?.config.name ?? "",
            defaultConfigurationIsVisible: 0
        )
        buildConfigs.forEach { addObject($0.config, reference: $0.reference) }
        let buildConfigListReference = proj.objects.generateReference(buildConfigList, spec.name)
        addObject(buildConfigList, reference: buildConfigListReference)

        for target in spec.targets {
            targetNativeReferences[target.name] =
                referenceGenerator.generate(
                    target.isLegacy ? PBXLegacyTarget.self : PBXNativeTarget.self,
                    target.name
                )

            let fileReference = PBXFileReference(
                sourceTree: .buildProductsDir,
                explicitFileType: target.type.fileExtension,
                path: target.filename,
                includeInIndex: 0
            )
            let fileReferenceReference = proj.objects.generateReference(fileReference, target.name)
            addObject(fileReference, reference: fileReferenceReference)
            targetFileReferences[target.name] = fileReferenceReference

            let buildFile = PBXBuildFile(
                fileRef: fileReferenceReference
            )
            let buildFileReference = proj.objects.generateReference(buildFile, fileReferenceReference)
            addObject(buildFile, reference: buildFileReference)
            targetBuildFiles[target.name] = (reference: buildFileReference, buildFile: buildFile)
        }

        let targets = try spec.targets.map(generateTarget)

        let productGroup = PBXGroup(
            children: Array(targetFileReferences.values),
            sourceTree: .group,
            name: "Products"
        )
        let productsReference = proj.objects.generateReference(productGroup, "Products")
        addObject(productGroup, reference: productsReference)
        topLevelGroups.insert(productsReference)

        if !carthageFrameworksByPlatform.isEmpty {
            var platformsReferences: [String] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup = PBXGroup(
                    children: fileReferences.sorted(),
                    sourceTree: .group,
                    name: platform,
                    path: platform
                )
                let platformGroupReference = proj.objects.generateReference(platformGroup, "Carthage" + platform)
                addObject(platformGroup, reference: platformGroupReference)
                platformsReferences.append(platformGroupReference)
            }
            let carthageGroup = PBXGroup(
                children: platformsReferences.sorted(),
                sourceTree: .group,
                name: "Carthage",
                path: carthageBuildPath
            )
            let carthageGroupReference = proj.objects.generateReference(carthageGroup, "Carthage")
            addObject(carthageGroup, reference: carthageGroupReference)
            frameworkFiles.append(carthageGroupReference)
        }

        if !frameworkFiles.isEmpty {
            let group = PBXGroup(
                children: frameworkFiles,
                sourceTree: .group,
                name: "Frameworks"
            )
            let groupReference = proj.objects.generateReference(group, "Frameworks")
            addObject(group, reference: groupReference)
            topLevelGroups.insert(groupReference)
        }

        for rootGroup in sourceGenerator.rootGroups {
            topLevelGroups.insert(rootGroup)
        }

        let mainGroup = PBXGroup(
            children: Array(topLevelGroups),
            sourceTree: .group,
            usesTabs: spec.options.usesTabs.map { $0 ? 1 : 0 },
            indentWidth: spec.options.indentWidth,
            tabWidth: spec.options.tabWidth
        )
        let mainGroupReference = proj.objects.generateReference(mainGroup, "Project")
        addObject(mainGroup, reference: mainGroupReference)

        sortGroups(group: mainGroup, reference: mainGroupReference)

        let projectAttributes: [String: Any] = ["LastUpgradeCheck": spec.xcodeVersion].merged(spec.attributes)
        let root = PBXProject(
            name: spec.name,
            reference: proj.rootObject,
            buildConfigurationList: buildConfigListReference,
            compatibilityVersion: "Xcode 3.2",
            mainGroup: mainGroup.reference,
            developmentRegion: spec.options.developmentLanguage ?? "en",
            knownRegions: sourceGenerator.knownRegions.sorted(),
            targets: targets.references,
            attributes: projectAttributes
        )
        proj.objects.projects.append(root)

        return proj
    }

    func sortGroups(group: PBXGroup, reference: String) {
        // sort children
        let children = group.children
            .flatMap { reference in
                return proj.objects.getFileElement(reference: reference).flatMap({ (reference: reference, object: $0) })
            }
            .sorted { child1, child2 in
                if child1.object.sortOrder == child2.object.sortOrder {
                    return child1.object.nameOrPath < child2.object.nameOrPath
                } else {
                    return child1.object.sortOrder < child2.object.sortOrder
                }
            }
        group.children = children.map { $0.reference }.filter { $0 != reference }

        // sort sub groups
        let childGroups = group.children.flatMap { reference in
            return proj.objects.groups[reference].flatMap({(group: $0, reference: reference)})
        }
        childGroups.forEach({ sortGroups(group: $0.group, reference: $0.reference) })
    }

    func generateTarget(_ target: Target) throws -> PBXTarget {

        sourceGenerator.targetName = target.name
        let carthageDependencies = getAllCarthageDependencies(target: target)

        let sourceFiles = try sourceGenerator.getAllSourceFiles(sources: target.sources)

        var plistPath: Path?
        var searchForPlist = true

        let configs: [(reference: String, configuration: XCBuildConfiguration)] = spec.configs.map { config in
            var buildSettings = spec.getTargetBuildSettings(target: target, config: config)

            // automatically set INFOPLIST_FILE path
            if !spec.targetHasBuildSetting("INFOPLIST_FILE", basePath: spec.basePath, target: target, config: config) {
                if searchForPlist {
                    plistPath = getInfoPlist(target.sources)
                    searchForPlist = false
                }
                if let plistPath = plistPath {
                    buildSettings["INFOPLIST_FILE"] = plistPath.byRemovingBase(path: spec.basePath)
                }
            }

            // automatically calculate bundle id
            if let bundleIdPrefix = spec.options.bundleIdPrefix,
                !spec.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", basePath: spec.basePath, target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name
                    .replacingOccurrences(of: "_", with: "-")
                    .components(separatedBy: characterSet)
                    .joined(separator: "")
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
            let buildConfiguration = XCBuildConfiguration(
                name: config.name,
                baseConfigurationReference: baseConfigurationReference,
                buildSettings: buildSettings
            )
            let buildConfigurationReference = proj.objects.generateReference(buildConfiguration, config.name + target.name)
            return (reference: buildConfigurationReference, configuration: buildConfiguration)
        }
        configs.forEach({ addObject($0.configuration, reference: $0.reference) })
        let buildConfigList = XCConfigurationList(
            buildConfigurations: configs.map({$0.reference}),
            defaultConfigurationName: ""
        )
        let buildConfigListReference = proj.objects.generateReference(buildConfigList, target.name)
        addObject(buildConfigList, reference: buildConfigListReference)

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

                let targetProxy = PBXContainerItemProxy(
                    containerPortal: proj.rootObject,
                    remoteGlobalIDString: targetNativeReferences[dependencyTargetName]!,
                    proxyType: .nativeTarget,
                    remoteInfo: dependencyTargetName
                )
                let targetProxyReference = proj.objects.generateReference(targetProxy, target.name)
                let targetDependency = PBXTargetDependency(
                    target: targetNativeReferences[dependencyTargetName]!,
                    targetProxy: targetProxyReference
                )
                let targetDependencyReference = proj.objects.generateReference(targetDependency, dependencyTargetName + target.name)
                addObject(targetProxy, reference: targetProxyReference)
                addObject(targetDependency, reference: targetDependencyReference)
                dependencies.append(targetDependencyReference)

                if (dependencyTarget.type.isLibrary || dependencyTarget.type.isFramework) && dependency.link {
                    let dependencyBuildFile = targetBuildFiles[dependencyTargetName]!
                    let buildFile = PBXBuildFile(
                        fileRef: dependencyBuildFile.buildFile.fileRef!
                    )
                    let buildFileReference = proj.objects.generateReference(buildFile, dependencyBuildFile.reference + target.name)
                    addObject(buildFile, reference: buildFileReference)
                    targetFrameworkBuildFiles.append(buildFileReference)
                }

                if embed && !dependencyTarget.type.isLibrary {

                    let embedSettings = dependency.buildSettings
                    let embedFile = PBXBuildFile(
                        fileRef: dependencyFileReference,
                        settings: embedSettings
                    )
                    let embedFileReference = proj.objects.generateReference(embedFile, dependencyFileReference + target.name)
                    addObject(embedFile, reference: embedFileReference)

                    if dependencyTarget.type.isExtension {
                        // embed app extension
                        extensions.append(embedFileReference)
                    } else if dependencyTarget.type.isFramework {
                        copyFrameworksReferences.append(embedFileReference)
                    } else if dependencyTarget.type.isApp && dependencyTarget.platform == .watchOS {
                        copyWatchReferences.append(embedFileReference)
                    } else {
                        copyResourcesReferences.append(embedFileReference)
                    }
                }

            case .framework:
                let fileReference: String
                if dependency.implicit {
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: spec.basePath,
                        sourceTree: .buildProductsDir
                    )
                } else {
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: spec.basePath
                    )
                }

                let buildFile = PBXBuildFile(
                    fileRef: fileReference
                )
                let buildFileReference = proj.objects.generateReference(buildFile, fileReference + target.name)
                addObject(buildFile, reference: buildFileReference)

                targetFrameworkBuildFiles.append(buildFileReference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = PBXBuildFile(
                        fileRef: fileReference,
                        settings: dependency.buildSettings
                    )
                    let embedFileReference = proj.objects.generateReference(embedFile, fileReference + target.name)
                    addObject(embedFile, reference: embedFileReference)
                    copyFrameworksReferences.append(embedFileReference)
                }
            case .carthage:
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependency.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = PBXBuildFile(
                    fileRef: fileReference
                )
                let buildFileReference = proj.objects.generateReference(buildFile, fileReference + target.name)
                addObject(buildFile, reference: buildFileReference)
                carthageFrameworksByPlatform[target.platform.carthageDirectoryName, default: []].insert(fileReference)

                targetFrameworkBuildFiles.append(buildFileReference)
                if target.platform == .macOS && target.type.isApp {
                    let embedFile = PBXBuildFile(
                        fileRef: fileReference,
                        settings: dependency.buildSettings
                    )
                    let embedFileReference = proj.objects.generateReference(embedFile, fileReference + target.name)
                    addObject(embedFile, reference: embedFileReference)
                    copyFrameworksReferences.append(embedFileReference)
                }
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [String] {
            let files = sourceFiles
                .filter { $0.buildPhase == buildPhase }
                .sorted { $0.path.lastComponent < $1.path.lastComponent }
            files.forEach { addObject($0.buildFile, reference: $0.reference) }
            return files.map { $0.reference }
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
                files: [],
                name: buildScript.name ?? "Run Script",
                inputPaths: buildScript.inputFiles,
                outputPaths: buildScript.outputFiles,
                shellPath: buildScript.shell ?? "/bin/sh",
                shellScript: shellScript
            )
            shellScriptPhase.runOnlyForDeploymentPostprocessing = buildScript.runOnlyWhenInstalling ? 1 : 0
            let shellScriptPhaseReference = proj.objects.generateReference(shellScriptPhase, String(describing: buildScript.name) + shellScript + target.name)
            addObject(shellScriptPhase, reference: shellScriptPhaseReference)
            buildPhases.append(shellScriptPhaseReference)
            return shellScriptPhase
        }

        _ = try target.prebuildScripts.map(getBuildScript)

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        if !sourcesBuildPhaseFiles.isEmpty {
            let sourcesBuildPhase = PBXSourcesBuildPhase(files: sourcesBuildPhaseFiles)
            let sourcesBuildPhaseReference = proj.objects.generateReference(sourcesBuildPhase, target.name)
            addObject(sourcesBuildPhase, reference: sourcesBuildPhaseReference)
            buildPhases.append(sourcesBuildPhaseReference)
        }

        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources) + copyResourcesReferences
        if !resourcesBuildPhaseFiles.isEmpty {
            let resourcesBuildPhase = PBXResourcesBuildPhase(files: resourcesBuildPhaseFiles)
            let resourcesBuildPhaseReference = proj.objects.generateReference(resourcesBuildPhase, target.name)
            addObject(resourcesBuildPhase, reference: resourcesBuildPhaseReference)
            buildPhases.append(resourcesBuildPhaseReference)
        }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers)
        if !headersBuildPhaseFiles.isEmpty && (target.type == .framework || target.type == .dynamicLibrary) {
            let headersBuildPhase = PBXHeadersBuildPhase(files: headersBuildPhaseFiles)
            let headersBuildPhaseReference = proj.objects.generateReference(headersBuildPhase, target.name)
            addObject(headersBuildPhase, reference: headersBuildPhaseReference)
            buildPhases.append(headersBuildPhaseReference)
        }

        if !targetFrameworkBuildFiles.isEmpty {
            let frameworkBuildPhase = PBXFrameworksBuildPhase(
                files: targetFrameworkBuildFiles,
                runOnlyForDeploymentPostprocessing: 0
            )
            let frameworkBuildPhaseReference = proj.objects.generateReference(frameworkBuildPhase, target.name)
            addObject(frameworkBuildPhase, reference: frameworkBuildPhaseReference)
            buildPhases.append(frameworkBuildPhaseReference)
        }

        if !extensions.isEmpty {
            let copyFilesPhase = PBXCopyFilesBuildPhase(
                dstPath: "",
                dstSubfolderSpec: .plugins,
                files: extensions
            )
            let copyFilesPhaseReference = proj.objects.generateReference(copyFilesPhase, target.name)
            addObject(copyFilesPhase, reference: copyFilesPhaseReference)
            buildPhases.append(copyFilesPhaseReference)
        }

        if !copyFrameworksReferences.isEmpty {
            let copyFilesPhase = PBXCopyFilesBuildPhase(
                dstPath: "",
                dstSubfolderSpec: .frameworks,
                files: copyFrameworksReferences
            )
            let copyFilesPhaseReference = proj.objects.generateReference(copyFilesPhase, "embed app extensions" + target.name)
            addObject(copyFilesPhase, reference: copyFilesPhaseReference)
            buildPhases.append(copyFilesPhaseReference)
        }

        if !copyWatchReferences.isEmpty {
            let copyFilesPhase = PBXCopyFilesBuildPhase(
                dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
                dstSubfolderSpec: .productsDirectory,
                files: copyWatchReferences
            )
            let copyFilesPhaseReference = proj.objects.generateReference(copyFilesPhase, "embed watch content" + target.name)
            addObject(copyFilesPhase, reference: copyFilesPhaseReference)
            buildPhases.append(copyFilesPhaseReference)
        }

        let carthageFrameworksToEmbed = Array(Set(
            carthageDependencies
                .filter { $0.embed ?? true }
                .map { $0.reference }
        ))
            .sorted()

        if !carthageFrameworksToEmbed.isEmpty {

            if target.type.isApp && target.platform != .macOS {
                let inputPaths = carthageFrameworksToEmbed
                    .map { "$(SRCROOT)/\(carthageBuildPath)/\(target.platform)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let outputPaths = carthageFrameworksToEmbed
                    .map { "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")" }
                let carthageScript = PBXShellScriptBuildPhase(
                    reference: referenceGenerator.generate(PBXShellScriptBuildPhase.self, "Carthage" + target.name),
                    files: [],
                    name: "Carthage",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh",
                    shellScript: "/usr/local/bin/carthage copy-frameworks\n"
                )
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
                productType: target.type
            )
        }
        addObject(pbxtarget)
        return pbxtarget
    }

    func getInfoPlist(_ sources: [TargetSource]) -> Path? {
        return sources
            .lazy
            .map { self.spec.basePath + $0.path }
            .flatMap { (path) -> Path? in
                if path.isFile {
                    return path.lastComponent == "Info.plist" ? path : nil
                } else {
                    return path.first(where: { $0.lastComponent == "Info.plist" })
                }
            }
            .first
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
