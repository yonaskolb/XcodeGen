import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcproj
import Yams

public class PBXProjGenerator {

    let project: Project

    let pbxProj: PBXProj
    var sourceGenerator: SourceGenerator!

    var targetObjects: [String: ObjectReference<PBXTarget>] = [:]
    var targetAggregateObjects: [String: ObjectReference<PBXAggregateTarget>] = [:]
    var targetBuildFiles: [String: ObjectReference<PBXBuildFile>] = [:]
    var targetFileReferences: [String: String] = [:]

    var carthageFrameworksByPlatform: [String: Set<String>] = [:]
    var frameworkFiles: [String] = []

    var generated = false

    var carthageBuildPath: String {
        return project.options.carthageBuildPath ?? "Carthage/Build"
    }

    public init(project: Project) {
        self.project = project
        pbxProj = PBXProj(rootObject: "", objectVersion: 46)
        sourceGenerator = SourceGenerator(project: project) { [unowned self] id, object in
            self.addObject(id: id, object)
        }
    }

    func addObject(id: String, _ object: PBXObject) -> String {
        let reference = pbxProj.objects.generateReference(object, id)
        pbxProj.objects.addObject(object, reference: reference)
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

        var derivedGroups: [ObjectReference<PBXGroup>] = []

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

        let pbxProject = createObject(
            id: project.name,
            PBXProject(
                name: project.name,
                buildConfigurationList: buildConfigList.reference,
                compatibilityVersion: "Xcode 3.2",
                mainGroup: mainGroup.reference,
                developmentRegion: project.options.developmentLanguage ?? "en"
            )
        )

        pbxProj.rootObject = pbxProject.reference

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

            if !target.isLegacy {
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
        }

        try project.targets.forEach(generateTarget)
        try project.aggregateTargets.forEach(generateAggregateTarget)

        let productGroup = createObject(
            id: "Products",
            PBXGroup(
                children: Array(targetFileReferences.values),
                sourceTree: .group,
                name: "Products"
            )
        )
        derivedGroups.append(productGroup)

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
            derivedGroups.append(group)
        }

        mainGroup.object.children = Array(sourceGenerator.rootGroups)
        sortGroups(group: mainGroup)
        // add derived groups at the end
        derivedGroups.forEach(sortGroups)
        mainGroup.object.children += derivedGroups
            .sorted { $0.object.nameOrPath.localizedStandardCompare($1.object.nameOrPath) == .orderedAscending }
            .map { $0.reference }

        let projectAttributes: [String: Any] = ["LastUpgradeCheck": project.xcodeVersion]
            .merged(project.attributes)
            .merged(generateTargetAttributes() ?? [:])

        pbxProject.object.knownRegions = sourceGenerator.knownRegions.sorted()
        let allTargets: [ObjectReference<PBXTarget>] = Array(targetObjects.values) + Array(targetAggregateObjects.values.map { ObjectReference(reference: $0.reference, object: $0.object) })
            pbxProject.object.targets = allTargets
                .sorted { $0.object.name < $1.object.name }
                .map { $0.reference }
        pbxProject.object.attributes = projectAttributes

        return pbxProj
    }

    func generateAggregateTarget(_ target: AggregateTarget) throws {

        let configs: [ObjectReference<XCBuildConfiguration>] = project.configs.map { config in

            let buildSettings = project.getBuildSettings(settings: target.settings, config: config)

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

        let dependencies: [String] = target.targets.map { generateTargetDependency(from: target.name, to: $0).reference }

        let buildConfigList = createObject(id: target.name, XCConfigurationList(
            buildConfigurations: configs.map { $0.reference },
            defaultConfigurationName: ""
        ))

        var buildPhases: [String] = []
        buildPhases += try target.buildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        let aggregateTarget = createObject(
            id: target.name,
            PBXAggregateTarget(
                name: target.name,
                buildConfigurationList: buildConfigList.reference,
                buildPhases: buildPhases,
                buildRules: [],
                dependencies: dependencies,
                productName: target.name,
                productReference: nil,
                productType: nil
            )
        )
        targetAggregateObjects[target.name] = aggregateTarget
    }

    func generateTargetDependency(from: String, to target: String) -> ObjectReference<PBXTargetDependency> {

        let targetProxy = createObject(
            id: "\(from)-\(target)",
            PBXContainerItemProxy(
                containerPortal: pbxProj.rootObject,
                remoteGlobalIDString: targetObjects[target]!.reference,
                proxyType: .nativeTarget,
                remoteInfo: target
            )
        )

        let targetDependency = createObject(
            id: "\(from)-\(target)",
            PBXTargetDependency(
                target: targetObjects[target]!.reference,
                targetProxy: targetProxy.reference
            )
        )
        return targetDependency
    }

    func generateBuildScript(targetName: String, buildScript: BuildScript) throws -> String {

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
        shellScriptPhase.showEnvVarsInLog = buildScript.showEnvVars
        return createObject(id: String(describing: buildScript.name) + shellScript + targetName, shellScriptPhase).reference
    }

    func generateTargetAttributes() -> [String: Any]? {

        var targetAttributes: [String: [String: Any]] = [:]

        let uiTestTargets = pbxProj.objects.nativeTargets.objectReferences.filter { $0.object.productType == .uiTestBundle }
        for uiTestTarget in uiTestTargets {

            // look up TEST_TARGET_NAME build setting
            func testTargetName(_ target: PBXTarget) -> String? {
                guard let configurationList = target.buildConfigurationList else { return nil }
                guard let buildConfigurationReferences = self.pbxProj.objects.configurationLists[configurationList]?.buildConfigurations else { return nil }

                let configs = buildConfigurationReferences
                    .compactMap { ref in self.pbxProj.objects.buildConfigurations[ref] }

                return configs
                    .compactMap { $0.buildSettings["TEST_TARGET_NAME"] as? String }
                    .first
            }

            guard let name = testTargetName(uiTestTarget.object) else { continue }
            guard let target = self.pbxProj.objects.targets(named: name).first else { continue }

            targetAttributes[uiTestTarget.reference, default: [:]].merge(["TestTargetID": target.reference])
        }

        func generateTargetAttributes(_ target: ProjectTarget, targetReference: String) {
            if !target.attributes.isEmpty {
                targetAttributes[targetReference, default: [:]].merge(target.attributes)
            }

            func getSingleBuildSetting(_ setting: String) -> String? {
                let settings = project.configs.compactMap {
                    project.getCombinedBuildSettings(basePath: project.basePath, target: target, config: $0)[setting] as? String
                }
                guard settings.count == project.configs.count,
                    let firstSetting = settings.first,
                    settings.filter({ $0 == firstSetting }).count == settings.count else {
                    return nil
                }
                return firstSetting
            }

            func setTargetAttribute(attribute: String, buildSetting: String) {
                if let setting = getSingleBuildSetting(buildSetting) {
                    targetAttributes[targetReference, default: [:]].merge([attribute: setting])
                }
            }

            setTargetAttribute(attribute: "ProvisioningStyle", buildSetting: "CODE_SIGN_STYLE")
            setTargetAttribute(attribute: "DevelopmentTeam", buildSetting: "DEVELOPMENT_TEAM")
        }

        for target in project.aggregateTargets {
            guard let targetReference = targetAggregateObjects[target.name]?.reference else {
                continue
            }
            generateTargetAttributes(target, targetReference: targetReference)
        }

        for target in project.targets {
            guard let targetReference = targetObjects[target.name]?.reference else {
                continue
            }
            generateTargetAttributes(target, targetReference: targetReference)
        }

        return targetAttributes.isEmpty ? nil : ["TargetAttributes": targetAttributes]
    }

    func sortGroups(group: ObjectReference<PBXGroup>) {
        // sort children
        let children = group.object.children
            .compactMap { reference -> ObjectReference<PBXFileElement>? in
                guard let fileElement = pbxProj.objects.getFileElement(reference: reference) else {
                    return nil
                }
                return ObjectReference(reference: reference, object: fileElement)
            }
            .sorted { child1, child2 in
                let sortOrder1 = child1.object.getSortOrder(groupSortPosition: project.options.groupSortPosition)
                let sortOrder2 = child2.object.getSortOrder(groupSortPosition: project.options.groupSortPosition)

                if sortOrder1 == sortOrder2 {
                    return child1.object.nameOrPath.localizedStandardCompare(child2.object.nameOrPath) == .orderedAscending
                } else {
                    return sortOrder1 < sortOrder2
                }
            }
        group.object.children = children.map { $0.reference }.filter { $0 != group.reference }

        // sort sub groups
        let childGroups = group.object.children.compactMap { reference -> ObjectReference<PBXGroup>? in
            guard let group = pbxProj.objects.groups[reference] else {
                return nil
            }
            return ObjectReference(reference: reference, object: group) }
        childGroups.forEach(sortGroups)
    }

    func generateTarget(_ target: Target) throws {

        sourceGenerator.targetName = target.name
        let carthageDependencies = getAllCarthageDependencies(target: target)

        let sourceFiles = try sourceGenerator.getAllSourceFiles(targetType: target.type, sources: target.sources)

        var plistPath: Path?
        var searchForPlist = true
        var anyDependencyRequiresObjCLinking = false

        var dependencies: [String] = []
        var targetFrameworkBuildFiles: [String] = []
        var frameworkBuildPaths = Set<String>()
        var copyFrameworksReferences: [String] = []
        var copyResourcesReferences: [String] = []
        var copyWatchReferences: [String] = []
        var extensions: [String] = []
        var carthageFrameworksToEmbed: [String] = []

        let targetDependencies = (target.transitivelyLinkDependencies ?? project.options.transitivelyLinkDependencies) ?
            getAllDependenciesPlusTransitiveNeedingEmbedding(target: target) : target.dependencies
        
        let directlyEmbedCarthage = target.directlyEmbedCarthageDependencies ?? !(target.platform.requiresSimulatorStripping && target.type.isApp)
        
        func getEmbedSettings(dependency: Dependency, codeSign: Bool) -> [String: Any] {
            var embedAttributes: [String] = []
            if codeSign {
                embedAttributes.append("CodeSignOnCopy")
            }
            if dependency.removeHeaders {
                embedAttributes.append("RemoveHeadersOnCopy")
            }
            return ["ATTRIBUTES": embedAttributes]
        }

        for dependency in targetDependencies {

            let embed = dependency.embed ?? target.shouldEmbedDependencies

            switch dependency.type {
            case .target:
                let dependencyTargetName = dependency.reference
                guard let dependencyTarget = project.getTarget(dependencyTargetName) else { continue }
                let dependencyFileReference = targetFileReferences[dependencyTargetName]!

                let targetDependency = generateTargetDependency(from: target.name, to: dependencyTargetName)

                dependencies.append(targetDependency.reference)

                let dependecyLinkage = dependencyTarget.defaultLinkage
                let link = dependency.link ?? ((dependecyLinkage == .dynamic && target.type != .staticLibrary)
                    || (dependecyLinkage == .static && target.type.isExecutable))
                if link {
                    let dependencyBuildFile = targetBuildFiles[dependencyTargetName]!
                    let buildFile = createObject(
                        id: dependencyBuildFile.reference + target.name,
                        PBXBuildFile(fileRef: dependencyBuildFile.object.fileRef!)
                    )
                    targetFrameworkBuildFiles.append(buildFile.reference)
                    
                    if !anyDependencyRequiresObjCLinking
                        && dependencyTarget.requiresObjCLinking ?? (dependencyTarget.type == .staticLibrary) {
                        anyDependencyRequiresObjCLinking = true
                    }
                }

                let embed = dependency.embed ?? (!dependencyTarget.type.isLibrary && (target.type.isApp
                    || (target.type.isTest && (dependencyTarget.type.isFramework || dependencyTarget.type == .bundle))))
                if embed {
                    let embedFile = createObject(
                        id: dependencyFileReference + target.name,
                        PBXBuildFile(
                            fileRef: dependencyFileReference,
                            settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? !dependencyTarget.type.isExecutable)
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
                guard target.type != .staticLibrary else { break }
                
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
                    id: "framework" + fileReference + target.name,
                    PBXBuildFile(fileRef: fileReference)
                )

                targetFrameworkBuildFiles.append(buildFile.reference)
                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = createObject(
                        id: "framework embed" + fileReference + target.name,
                        PBXBuildFile(fileRef: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    copyFrameworksReferences.append(embedFile.reference)
                }
                
                let buildPath = Path(dependency.reference).parent().string
                frameworkBuildPaths.insert(buildPath)

            case .carthage:
                guard target.type != .staticLibrary else { break }
                
                var platformPath = Path(getCarthageBuildPath(platform: target.platform))
                var frameworkPath = platformPath + dependency.reference
                if frameworkPath.extension == nil {
                    frameworkPath = Path(frameworkPath.string + ".framework")
                }
                let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                let buildFile = createObject(
                    id: "carthage" + fileReference + target.name,
                    PBXBuildFile(fileRef: fileReference)
                )

                carthageFrameworksByPlatform[target.platform.carthageDirectoryName, default: []].insert(fileReference)

                targetFrameworkBuildFiles.append(buildFile.reference)
                
                // Embedding handled by iterating over `carthageDependencies` below
            }
        }
        
        for dependency in carthageDependencies {
            guard target.type != .staticLibrary else { break }
            
            let embed = dependency.embed ?? target.shouldEmbedDependencies
            
            var platformPath = Path(getCarthageBuildPath(platform: target.platform))
            var frameworkPath = platformPath + dependency.reference
            if frameworkPath.extension == nil {
                frameworkPath = Path(frameworkPath.string + ".framework")
            }
            let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)
            
            if embed {
                if directlyEmbedCarthage {
                    let embedFile = createObject(
                        id: "carthage embed" + fileReference + target.name,
                        PBXBuildFile(fileRef: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    copyFrameworksReferences.append(embedFile.reference)
                } else  {
                    carthageFrameworksToEmbed.append(dependency.reference)
                }
            }
        }

        let fileReference = targetFileReferences[target.name]
        var buildPhases: [String] = []

        func getBuildFilesForSourceFiles(_ sourceFiles: [SourceFile]) -> [String] {
            let files = sourceFiles
                .reduce(into: [SourceFile]()) { output, sourceFile in
                    if !output.contains(where: { $0.fileReference == sourceFile.fileReference }) {
                        output.append(sourceFile)
                    }
                }
                .sorted { $0.path.lastComponent < $1.path.lastComponent }
            return files.map { createObject(id: $0.fileReference + target.name, $0.buildFile) }
                .map { $0.reference }
        }
        
        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [String] {
            let filteredSourceFiles = sourceFiles
                .filter { $0.buildPhase?.buildPhase == buildPhase }
            return getBuildFilesForSourceFiles(filteredSourceFiles)
        }
        
        func getBuildFilesForCopyFilesPhases() -> [TargetSource.BuildPhase.CopyFilesSettings: [String]] {
            var sourceFilesByCopyFiles: [TargetSource.BuildPhase.CopyFilesSettings: [SourceFile]] = [:]
            for sourceFile in sourceFiles {
                guard case let .copyFiles(copyFilesSettings)? = sourceFile.buildPhase else { continue }
                sourceFilesByCopyFiles[copyFilesSettings, default: []].append(sourceFile)
            }
            return sourceFilesByCopyFiles.mapValues { getBuildFilesForSourceFiles($0) }
        }

        buildPhases += try target.prebuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        let sourcesBuildPhase = createObject(id: target.name, PBXSourcesBuildPhase(files: sourcesBuildPhaseFiles))
        buildPhases.append(sourcesBuildPhase.reference)

        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources) + copyResourcesReferences
        if !resourcesBuildPhaseFiles.isEmpty {
            let resourcesBuildPhase = createObject(id: target.name, PBXResourcesBuildPhase(files: resourcesBuildPhaseFiles))
            buildPhases.append(resourcesBuildPhase.reference)
        }
        
        
        let buildSettings = project.getCombinedBuildSettings(basePath: project.basePath, target: target, config: project.configs[0])
        let swiftObjCInterfaceHeader = buildSettings["SWIFT_OBJC_INTERFACE_HEADER_NAME"] as? String
        
        if target.type == .staticLibrary
            && swiftObjCInterfaceHeader != ""
            && sourceFiles.contains(where: { $0.buildPhase == .sources && $0.path.extension == "swift" }) {
            
            let inputPaths = ["$(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"]
            let outputPaths = ["$(BUILT_PRODUCTS_DIR)/include/$(PRODUCT_MODULE_NAME)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"]
            let script = createObject(
                id: "Swift.h" + target.name,
                PBXShellScriptBuildPhase(
                    files: [],
                    name: "Copy Swift Objective-C Interface Header",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh",
                    shellScript: "ditto \"${SCRIPT_INPUT_FILE_0}\" \"${SCRIPT_OUTPUT_FILE_0}\"\n"
                )
            )
            buildPhases.append(script.reference)
        }
        
        let copyFilesBuildPhasesFiles = getBuildFilesForCopyFilesPhases()
        if !copyFilesBuildPhasesFiles.isEmpty {
            for (copyFiles, buildPhaseFiles) in copyFilesBuildPhasesFiles {
                let copyFilesBuildPhase = createObject(
                    id: "copy files" + copyFiles.destination.rawValue + copyFiles.subpath + target.name,
                    PBXCopyFilesBuildPhase(
                        dstPath: copyFiles.subpath,
                        dstSubfolderSpec: copyFiles.destination.destination,
                        files: buildPhaseFiles
                    )
                )
                
                buildPhases.append(copyFilesBuildPhase.reference)
            }
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
                    name: "Embed App Extensions",
                    files: extensions
                )
            )

            buildPhases.append(copyFilesPhase.reference)
        }

        copyFrameworksReferences += getBuildFilesForPhase(.frameworks)
        if !copyFrameworksReferences.isEmpty {

            let copyFilesPhase = createObject(
                id: "embed frameworks" + target.name,
                PBXCopyFilesBuildPhase(
                    dstPath: "",
                    dstSubfolderSpec: .frameworks,
                    name: "Embed Frameworks",
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
                    name: "Embed Watch Content",
                    files: copyWatchReferences
                )
            )

            buildPhases.append(copyFilesPhase.reference)
        }
        
        if !carthageFrameworksToEmbed.isEmpty {

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

        let buildRules = target.buildRules.map { buildRule in
            createObject(
                id: "\(target.name)-\(buildRule.action)-\(buildRule.fileType)",
                PBXBuildRule(
                    compilerSpec: buildRule.action.compilerSpec,
                    fileType: buildRule.fileType.fileType,
                    isEditable: true,
                    filePatterns: buildRule.fileType.pattern,
                    name: buildRule.name ?? "Build Rule",
                    outputFiles: buildRule.outputFiles,
                    outputFilesCompilerFlags: buildRule.outputFilesCompilerFlags,
                    script: buildRule.action.script
                )
            ).reference
        }

        buildPhases += try target.postbuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }
        
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
            
            // objc linkage
            if anyDependencyRequiresObjCLinking {
                let otherLinkingFlags = "OTHER_LDFLAGS"
                let objCLinking = "-ObjC"
                if var array = buildSettings[otherLinkingFlags] as? [String] {
                    array.append(objCLinking)
                    buildSettings[otherLinkingFlags] = array
                } else if let string = buildSettings[otherLinkingFlags] as? String {
                    buildSettings[otherLinkingFlags] = [string, objCLinking]
                } else {
                    buildSettings[otherLinkingFlags] = ["$(inherited)", objCLinking]
                }
            }
            
            // set Carthage search paths
            let configFrameworkBuildPaths: [String]
            if !carthageDependencies.isEmpty {
                let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + getCarthageBuildPath(platform: target.platform)
                configFrameworkBuildPaths = [carthagePlatformBuildPath] + Array(frameworkBuildPaths).sorted()
            } else {
                configFrameworkBuildPaths = Array(frameworkBuildPaths).sorted()
            }
            
            // set framework search paths
            if !configFrameworkBuildPaths.isEmpty {
                let frameworkSearchPaths = "FRAMEWORK_SEARCH_PATHS"
                if var array = buildSettings[frameworkSearchPaths] as? [String] {
                    array.append(contentsOf: configFrameworkBuildPaths)
                    buildSettings[frameworkSearchPaths] = array
                } else if let string = buildSettings[frameworkSearchPaths] as? String {
                    buildSettings[frameworkSearchPaths] = [string] + configFrameworkBuildPaths
                } else {
                    buildSettings[frameworkSearchPaths] = ["$(inherited)"] + configFrameworkBuildPaths
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

        let targetObject = targetObjects[target.name]!.object

        targetObject.name = target.name
        targetObject.buildConfigurationList = buildConfigList.reference
        targetObject.buildPhases = buildPhases
        targetObject.dependencies = dependencies
        targetObject.productName = target.name
        targetObject.buildRules = buildRules
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

    func getAllCarthageDependencies(target: Target) -> [Dependency] {
        // this is used to resolve cyclical target dependencies
        var visitedTargets: Set<String> = []
        var frameworks: [String: Dependency] = [:]

        var queue: [Target] = [target]
        while !queue.isEmpty {
            let target = queue.removeFirst()
            if visitedTargets.contains(target.name) {
                continue
            }

            for dependency in target.dependencies {
                // don't overwrite frameworks, to allow top level ones to rule
                if frameworks.contains(reference: dependency.reference) {
                    continue
                }
                
                switch dependency.type {
                case .carthage:
                    frameworks[dependency.reference] = dependency
                case .target:
                    if let target = project.getTarget(dependency.reference) {
                        queue.append(target)
                    }
                default:
                    break
                }
            }

            visitedTargets.update(with: target.name)
        }

        return frameworks.sorted(by: { $0.key < $1.key }).map { $0.value }
    }

    func getAllDependenciesPlusTransitiveNeedingEmbedding(target topLevelTarget: Target) -> [Dependency] {
        // this is used to resolve cyclical target dependencies
        var visitedTargets: Set<String> = []
        var dependencies: [String: Dependency] = [:]
        var queue: [Target] = [topLevelTarget]
        while !queue.isEmpty {
            let target = queue.removeFirst()
            if visitedTargets.contains(target.name) {
                continue
            }

            let isTopLevel = target == topLevelTarget

            for dependency in target.dependencies {
                // don't overwrite dependencies, to allow top level ones to rule
                if dependencies.contains(reference: dependency.reference) {
                    continue
                }

                // don't want a dependency if it's going to be embedded or statically linked in a non-top level target
                // in .target check we filter out targets that will embed all of their dependencies
                switch dependency.type {
                case .framework, .carthage:
                    if isTopLevel || dependency.embed == nil {
                        dependencies[dependency.reference] = dependency
                    }
                case .target:
                    if let dependencyTarget = project.getTarget(dependency.reference) {
                        if isTopLevel || dependency.embed == nil {
                            dependencies[dependency.reference] = dependency
                            if !dependencyTarget.shouldEmbedDependencies {
                                // traverse target's dependencies if it doesn't embed them itself
                                queue.append(dependencyTarget)
                            }
                        }
                    }
                }
            }

            visitedTargets.update(with: target.name)
        }

        return dependencies.sorted(by: { $0.key < $1.key }).map { $0.value }
    }
}

extension Target {

    var shouldEmbedDependencies: Bool {
        return type.isApp || type.isTest
    }
}

extension Platform {
    /// - returns: `true` for platforms that the app store requires simulator slices to be stripped.
    public var requiresSimulatorStripping: Bool {
        switch self {
        case .iOS, .tvOS, .watchOS:
            return true
        case .macOS:
            return false
        }
    }
}

extension PBXFileElement {

    public func getSortOrder(groupSortPosition: SpecOptions.GroupSortPosition) -> Int {
        if type(of: self).isa == "PBXGroup" {
            switch groupSortPosition {
            case .top: return -1
            case .bottom: return 1
            case .none: return 0
            }
        } else {
            return 0
        }
    }
}
