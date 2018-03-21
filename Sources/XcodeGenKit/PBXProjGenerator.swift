import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcproj
import Yams

public class PBXProjGenerator {

    let project: Project

    let proj: PBXProj
    var sourceGenerator: SourceGenerator!

    var targetObjects: [String: ObjectReference<PBXTarget>] = [:]
    var targetBuildFiles: [String: ObjectReference<PBXBuildFile>] = [:]
    var targetFileReferences: [String: String] = [:]
    var topLevelGroups: Set<String> = []
    var carthageFrameworksByPlatform: [String: Set<String>] = [:]
    var frameworkFiles: [String] = []

    var generated = false

    var carthageBuildPath: String {
        return project.options.carthageBuildPath ?? "Carthage/Build"
    }

    public init(project: Project) {
        self.project = project
        proj = PBXProj(rootObject: "", objectVersion: 46)
        sourceGenerator = SourceGenerator(project: project) { [unowned self] id, object in
            self.addObject(id: id, object)
        }
    }

    func addObject(id: String, _ object: PBXObject) -> String {
        let reference = proj.objects.generateReference(object, id)
        proj.objects.addObject(object, reference: reference)
        return reference
    }

    func createObject<T>(id: String, _ object: T) -> ObjectReference<T> {
        let reference = addObject(id: id, object)
        return ObjectReference(reference: reference, object: object)
    }

    public func generate() throws -> PBXProj {
        if generated {
            fatalError("Cannot use PBXProjGenerator to generate more than once")
        }
        generated = true

        for group in project.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let buildConfigs: [ObjectReference<XCBuildConfiguration>] = project.configs.map { config in
            let buildSettings = project.getProjectBuildSettings(config: config)
            var baseConfigurationReference: String?
            if let configPath = project.configFiles[config.name] {
                baseConfigurationReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath)
            }
            return createObject(
                id: config.name,
                XCBuildConfiguration(
                    name: config.name,
                    baseConfigurationReference: baseConfigurationReference,
                    buildSettings: buildSettings
                )
            )
        }

        let configName = project.options.defaultConfig ?? buildConfigs.first?.object.name ?? ""
        let buildConfigList = createObject(
            id: project.name,
            XCConfigurationList(
                buildConfigurations: buildConfigs.map { $0.reference },
                defaultConfigurationName: configName
            )
        )

        let mainGroup = createObject(
            id: "Project",
            PBXGroup(
                children: [],
                sourceTree: .group,
                usesTabs: project.options.usesTabs,
                indentWidth: project.options.indentWidth,
                tabWidth: project.options.tabWidth
            )
        )

        let projectRef = createObject(
            id: project.name,
            PBXProject(
                name: project.name,
                buildConfigurationList: buildConfigList.reference,
                compatibilityVersion: "Xcode 3.2",
                mainGroup: mainGroup.reference,
                developmentRegion: project.options.developmentLanguage ?? "en"
            )
        )

        proj.rootObject = projectRef.reference

        for target in project.targets {
            let targetObject: PBXTarget

            if target.isLegacy {
                targetObject = PBXLegacyTarget(
                    name: target.name,
                    buildToolPath: target.legacy?.toolPath,
                    buildArgumentsString: target.legacy?.arguments,
                    passBuildSettingsInEnvironment: target.legacy?.passSettings ?? false,
                    buildWorkingDirectory: target.legacy?.workingDirectory
                )
            } else {
                targetObject = PBXNativeTarget(name: target.name)
            }

            targetObjects[target.name] = createObject(id: target.name, targetObject)

            var explicitFileType: String?
            var lastKnownFileType: String?
            let fileType = PBXFileReference.fileType(path: Path(target.filename))
            if target.platform == .macOS || target.platform == .watchOS || target.type == .framework {
                explicitFileType = fileType
            } else {
                lastKnownFileType = fileType
            }

            let fileReference = createObject(
                id: target.name,
                PBXFileReference(
                    sourceTree: .buildProductsDir,
                    explicitFileType: explicitFileType,
                    lastKnownFileType: lastKnownFileType,
                    path: target.filename,
                    includeInIndex: false
                )
            )

            targetFileReferences[target.name] = fileReference.reference
            targetBuildFiles[target.name] = createObject(
                id: fileReference.reference,
                PBXBuildFile(fileRef: fileReference.reference)
            )
        }

        try project.targets.forEach(generateTarget)

        let productGroup = createObject(
            id: "Products",
            PBXGroup(
                children: Array(targetFileReferences.values),
                sourceTree: .group,
                name: "Products"
            )
        )
        topLevelGroups.insert(productGroup.reference)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            var platformReferences: [String] = []
            for (platform, fileReferences) in carthageFrameworksByPlatform {
                let platformGroup: ObjectReference<PBXGroup> = createObject(
                    id: "Carthage" + platform,
                    PBXGroup(
                        children: fileReferences.sorted(),
                        sourceTree: .group,
                        path: platform
                    )
                )
                platformReferences.append(platformGroup.reference)
                platforms.append(platformGroup.object)
            }
            let carthageGroup = createObject(
                id: "Carthage",
                PBXGroup(
                    children: platformReferences.sorted(),
                    sourceTree: .group,
                    name: "Carthage",
                    path: carthageBuildPath
                )
            )
            frameworkFiles.append(carthageGroup.reference)
        }

        if !frameworkFiles.isEmpty {
            let group = createObject(
                id: "Frameworks",
                PBXGroup(
                    children: frameworkFiles,
                    sourceTree: .group,
                    name: "Frameworks"
                )
            )
            topLevelGroups.insert(group.reference)
        }

        for rootGroup in sourceGenerator.rootGroups {
            topLevelGroups.insert(rootGroup)
        }

        mainGroup.object.children = Array(topLevelGroups)
        sortGroups(group: mainGroup)

        let projectAttributes: [String: Any] = ["LastUpgradeCheck": project.xcodeVersion]
            .merged(project.attributes)
            .merged(generateTargetAttributes() ?? [:])

        projectRef.object.knownRegions = sourceGenerator.knownRegions.sorted()
        projectRef.object.targets = targetObjects.values.sorted { $0.object.name < $1.object.name }.map { $0.reference }
        projectRef.object.attributes = projectAttributes

        return proj
    }

    func generateTargetAttributes() -> [String: Any]? {

        var targetAttributes: [String: Any] = [:]

        // look up TEST_TARGET_NAME build setting
        func testTargetName(_ target: PBXTarget) -> String? {
            guard let configurationList = target.buildConfigurationList else { return nil }
            guard let buildConfigurationReferences = self.proj.objects.configurationLists[configurationList]?.buildConfigurations else { return nil }

            let configs = buildConfigurationReferences
                .flatMap { ref in self.proj.objects.buildConfigurations[ref] }

            return configs
                .flatMap { $0.buildSettings["TEST_TARGET_NAME"] as? String }
                .first
        }

        let uiTestTargets = proj.objects.nativeTargets.objectReferences.filter { $0.object.productType == .uiTestBundle }

        for uiTestTarget in uiTestTargets {
            guard let name = testTargetName(uiTestTarget.object) else { continue }
            guard let target = self.proj.objects.targets(named: name).first else { continue }

            targetAttributes[uiTestTarget.reference] = ["TestTargetID": target.reference]
        }

        guard !targetAttributes.isEmpty else { return nil }

        return [
            "TargetAttributes": targetAttributes,
        ]
    }

    func sortGroups(group: ObjectReference<PBXGroup>) {
        // sort children
        let children = group.object.children
            .flatMap { reference -> ObjectReference<PBXFileElement>? in
                guard let fileElement = proj.objects.getFileElement(reference: reference) else {
                    return nil
                }
                return ObjectReference(reference: reference, object: fileElement)
            }
            .sorted { child1, child2 in
                if child1.object.sortOrder == child2.object.sortOrder {
                    return child1.object.nameOrPath < child2.object.nameOrPath
                } else {
                    return child1.object.sortOrder < child2.object.sortOrder
                }
            }
        group.object.children = children.map { $0.reference }.filter { $0 != group.reference }

        // sort sub groups
        let childGroups = group.object.children.flatMap { reference -> ObjectReference<PBXGroup>? in
            guard let group = proj.objects.groups[reference] else {
                return nil
            }
            return ObjectReference(reference: reference, object: group) }
        childGroups.forEach(sortGroups)
    }

    func generateTarget(_ target: Target) throws {

        sourceGenerator.targetName = target.name
        let carthageDependencies = getAllCarthageDependencies(target: target)

        let sourceFiles = try sourceGenerator.getAllSourceFiles(sources: target.sources)

        var plistPath: Path?
        var searchForPlist = true

        let configs: [ObjectReference<XCBuildConfiguration>] = project.configs.map { config in
            var buildSettings = project.getTargetBuildSettings(target: target, config: config)

            // automatically set INFOPLIST_FILE path
            if !project.targetHasBuildSetting("INFOPLIST_FILE", basePath: project.basePath, target: target, config: config) {
                if searchForPlist {
                    plistPath = getInfoPlist(target.sources)
                    searchForPlist = false
                }
                if let plistPath = plistPath {
                    buildSettings["INFOPLIST_FILE"] = plistPath.byRemovingBase(path: project.basePath)
                }
            }

            // automatically calculate bundle id
            if let bundleIdPrefix = project.options.bundleIdPrefix,
                !project.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", basePath: project.basePath, target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name
                    .replacingOccurrences(of: "_", with: "-")
                    .components(separatedBy: characterSet)
                    .joined(separator: "")
                buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleIdPrefix + "." + escapedTargetName
            }

            // automatically set test target name
            if target.type == .uiTestBundle,
                !project.targetHasBuildSetting("TEST_TARGET_NAME", basePath: project.basePath, target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                        let dependencyTarget = project.getTarget(dependency.reference),
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
                baseConfigurationReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath)
            }
            let buildConfig = XCBuildConfiguration(
                name: config.name,
                baseConfigurationReference: baseConfigurationReference,
                buildSettings: buildSettings
            )
            return createObject(id: config.name + target.name, buildConfig)
        }

        let buildConfigList = createObject(id: target.name, XCConfigurationList(
            buildConfigurations: configs.map { $0.reference },
            defaultConfigurationName: ""
        ))

        var dependencies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var copyFrameworksReferences: [String] = []
        var copyResourcesReferences: [String] = []
        var copyWatchReferences: [String] = []
        var extensions: [String] = []

        for dependency in target.dependencies {

            let embed = dependency.embed ?? target.shouldEmbedDependencies
            switch dependency.type {
            case .target:
                let dependencyTargetName = dependency.reference
                guard let dependencyTarget = project.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetProxy = createObject(
                    id: target.name,
                    PBXContainerItemProxy(
                        containerPortal: proj.rootObject,
                        remoteGlobalIDString: targetObjects[dependencyTargetName]!.reference,
                        proxyType: .nativeTarget,
                        remoteInfo: dependencyTargetName
                    )
                )

                let targetDependency = createObject(
                    id: dependencyTargetName + target.name,
                    PBXTargetDependency(
                        target: targetObjects[dependencyTargetName]!.reference,
                        targetProxy: targetProxy.reference
                    )
                )

                dependencies.append(targetDependency.reference)

                if (dependencyTarget.type.isLibrary || dependencyTarget.type.isFramework) && dependency.link {
                    let dependencyBuildFile = targetBuildFiles[dependencyTargetName]!
                    let buildFile = createObject(
                        id: dependencyBuildFile.reference + target.name,
                        PBXBuildFile(fileRef: dependencyBuildFile.object.fileRef!)
                    )
                    targetFrameworkBuildFiles.append(buildFile.reference)
                }

                if (dependency.embed ?? target.type.isApp) && !dependencyTarget.type.isLibrary {

                    let embedFile = createObject(
                        id: dependencyFileReference + target.name,
                        PBXBuildFile(
                            fileRef: dependencyFileReference,
                            settings: dependency.buildSettings
                        )
                    )

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
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: project.basePath,
                        sourceTree: .buildProductsDir
                    )
                } else {
                    fileReference = sourceGenerator.getFileReference(
                        path: Path(dependency.reference),
                        inPath: project.basePath
                    )
                }

                let buildFile = createObject(
                    id: fileReference + target.name,
                    PBXBuildFile(fileRef: fileReference)
                )

                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = createObject(
                        id: fileReference + target.name,
                        PBXBuildFile(fileRef: fileReference, settings: dependency.buildSettings)
                    )
                    copyFrameworksReferences.append(embedFile.reference)
                }
            case .carthage:
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependency.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = createObject(
                    id: fileReference + target.name,
                    PBXBuildFile(fileRef: fileReference)
                )

                carthageFrameworksByPlatform[target.platform.carthageDirectoryName, default: []].insert(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
                if target.platform == .macOS && embed {
                    let embedFile = createObject(
                        id: fileReference + target.name,
                        PBXBuildFile(fileRef: fileReference, settings: dependency.buildSettings)
                    )
                    copyFrameworksReferences.append(embedFile.reference)
                }
            }
        }

        let fileReference = targetFileReferences[target.name]!
        var buildPhases: [String] = []

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [String] {
            let files = sourceFiles
                .filter { $0.buildPhase == buildPhase }
                .reduce(into: [SourceFile]()) { output, sourceFile in
                    if !output.contains(where: { $0.fileReference == sourceFile.fileReference }) {
                        output.append(sourceFile)
                    }
                }
                .sorted { $0.path.lastComponent < $1.path.lastComponent }
            return files.map { createObject(id: $0.fileReference + target.name, $0.buildFile) }
                .map { $0.reference }
        }

        func generateBuildScript(buildScript: BuildScript) throws {

            let shellScript: String
            switch buildScript.script {
            case let .path(path):
                shellScript = try (project.basePath + path).read()
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
            shellScriptPhase.runOnlyForDeploymentPostprocessing = buildScript.runOnlyWhenInstalling
            let shellScriptPhaseReference = createObject(id: String(describing: buildScript.name) + shellScript + target.name, shellScriptPhase)
            buildPhases.append(shellScriptPhaseReference.reference)
        }

        try target.prebuildScripts.forEach(generateBuildScript)

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        if !sourcesBuildPhaseFiles.isEmpty {
            let sourcesBuildPhase = createObject(id: target.name, PBXSourcesBuildPhase(files: sourcesBuildPhaseFiles))
            buildPhases.append(sourcesBuildPhase.reference)
        }

        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources) + copyResourcesReferences
        if !resourcesBuildPhaseFiles.isEmpty {
            let resourcesBuildPhase = createObject(id: target.name, PBXResourcesBuildPhase(files: resourcesBuildPhaseFiles))
            buildPhases.append(resourcesBuildPhase.reference)
        }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers)
        if !headersBuildPhaseFiles.isEmpty && (target.type == .framework || target.type == .dynamicLibrary) {
            let headersBuildPhase = createObject(id: target.name, PBXHeadersBuildPhase(files: headersBuildPhaseFiles))
            buildPhases.append(headersBuildPhase.reference)
        }

        if !targetFrameworkBuildFiles.isEmpty {

            let frameworkBuildPhase = createObject(
                id: target.name,
                PBXFrameworksBuildPhase(files: targetFrameworkBuildFiles)
            )
            buildPhases.append(frameworkBuildPhase.reference)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = createObject(
                id: "embed app extensions" + target.name,
                PBXCopyFilesBuildPhase(
                    dstPath: "",
                    dstSubfolderSpec: .plugins,
                    files: extensions
                )
            )

            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyFrameworksReferences.isEmpty {

            let copyFilesPhase = createObject(
                id: "embed frameworks" + target.name,
                PBXCopyFilesBuildPhase(
                    dstPath: "",
                    dstSubfolderSpec: .frameworks,
                    files: copyFrameworksReferences
                )
            )

            buildPhases.append(copyFilesPhase.reference)
        }

        if !copyWatchReferences.isEmpty {

            let copyFilesPhase = createObject(
                id: "embed watch content" + target.name,
                PBXCopyFilesBuildPhase(
                    dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
                    dstSubfolderSpec: .productsDirectory,
                    files: copyWatchReferences
                )
            )

            buildPhases.append(copyFilesPhase.reference)
        }

        let carthageFrameworksToEmbed = Array(Set(
            carthageDependencies
                .filter { $0.embed ?? target.shouldEmbedDependencies }
                .map { $0.reference }
        ))
            .sorted()

        if !carthageFrameworksToEmbed.isEmpty && target.platform != .macOS {

            let inputPaths = carthageFrameworksToEmbed
                .map { "$(SRCROOT)/\(carthageBuildPath)/\(target.platform)/\($0)\($0.contains(".") ? "" : ".framework")" }
            let outputPaths = carthageFrameworksToEmbed
                .map { "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")" }
            let carthageExecutable = project.options.carthageExecutablePath ?? "carthage"
            let carthageScript = createObject(
                id: "Carthage" + target.name,
                PBXShellScriptBuildPhase(
                    files: [],
                    name: "Carthage",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh",
                    shellScript: "\(carthageExecutable) copy-frameworks\n"
                )
            )
            buildPhases.append(carthageScript.reference)
        }

        try target.postbuildScripts.forEach(generateBuildScript)

        let targetObject = targetObjects[target.name]!.object

        targetObject.name = target.name
        targetObject.buildConfigurationList = buildConfigList.reference
        targetObject.buildPhases = buildPhases
        targetObject.dependencies = dependencies
        targetObject.productName = target.name
        targetObject.productReference = fileReference
        if !target.isLegacy {
            targetObject.productType = target.type
        }
    }

    func getInfoPlist(_ sources: [TargetSource]) -> Path? {
        return sources
            .lazy
            .map { self.project.basePath + $0.path }
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
                if let target = project.getTarget(targetName) {
                    frameworks += getAllCarthageDependencies(target: target, visitedTargets: visitedTargets)
                }
            default: break
            }
        }
        return frameworks
    }
}

extension Target {

    var shouldEmbedDependencies: Bool {
        return type.isApp || type.isTest
    }
}
