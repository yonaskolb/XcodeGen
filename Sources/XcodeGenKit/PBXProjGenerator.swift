import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import Yams

public class PBXProjGenerator {

    let project: Project

    let pbxProj: PBXProj
    let projectDirectory: Path?
    let carthageResolver: CarthageDependencyResolver

    var sourceGenerator: SourceGenerator!

    var targetObjects: [String: PBXTarget] = [:]
    var targetAggregateObjects: [String: PBXAggregateTarget] = [:]
    var targetFileReferences: [String: PBXFileReference] = [:]
    var sdkFileReferences: [String: PBXFileReference] = [:]
    var packageReferences: [String: XCRemoteSwiftPackageReference] = [:]

    var carthageFrameworksByPlatform: [String: Set<PBXFileElement>] = [:]
    var frameworkFiles: [PBXFileElement] = []

    var generated = false

    public init(project: Project, projectDirectory: Path? = nil) {
        self.project = project
        carthageResolver = CarthageDependencyResolver(project: project)
        pbxProj = PBXProj(rootObject: nil, objectVersion: project.objectVersion)
        self.projectDirectory = projectDirectory
        sourceGenerator = SourceGenerator(project: project,
                                          pbxProj: pbxProj,
                                          projectDirectory: projectDirectory)
    }

    @discardableResult
    func addObject<T: PBXObject>(_ object: T, context: String? = nil) -> T {
        pbxProj.add(object: object)
        object.context = context
        return object
    }

    public func generate() throws -> PBXProj {
        if generated {
            fatalError("Cannot use PBXProjGenerator to generate more than once")
        }
        generated = true

        for group in project.fileGroups {
            try sourceGenerator.getFileGroups(path: group)
        }

        let localPackages = Set(project.localPackages)
        for package in localPackages {
            let path = project.basePath + Path(package).normalize()
            try sourceGenerator.createLocalPackage(path: path)
        }

        let buildConfigs: [XCBuildConfiguration] = project.configs.map { config in
            let buildSettings = project.getProjectBuildSettings(config: config)
            var baseConfiguration: PBXFileReference?
            if let configPath = project.configFiles[config.name],
                let fileReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference {
                baseConfiguration = fileReference
            }
            let buildConfig = addObject(
                XCBuildConfiguration(
                    name: config.name,
                    buildSettings: buildSettings
                )
            )
            buildConfig.baseConfiguration = baseConfiguration
            return buildConfig
        }

        let configName = project.options.defaultConfig ?? buildConfigs.first?.name ?? ""
        let buildConfigList = addObject(
            XCConfigurationList(
                buildConfigurations: buildConfigs,
                defaultConfigurationName: configName
            )
        )

        var derivedGroups: [PBXGroup] = []

        let mainGroup = addObject(
            PBXGroup(
                children: [],
                sourceTree: .group,
                usesTabs: project.options.usesTabs,
                indentWidth: project.options.indentWidth,
                tabWidth: project.options.tabWidth
            )
        )

        let pbxProject = addObject(
            PBXProject(
                name: project.name,
                buildConfigurationList: buildConfigList,
                compatibilityVersion: project.compatibilityVersion,
                mainGroup: mainGroup,
                developmentRegion: project.options.developmentLanguage ?? "en"
            )
        )

        pbxProj.rootObject = pbxProject

        for target in project.targets {
            let targetObject: PBXTarget

            if target.isLegacy {
                targetObject = PBXLegacyTarget(
                    name: target.name,
                    buildToolPath: target.legacy?.toolPath,
                    buildArgumentsString: target.legacy?.arguments,
                    passBuildSettingsInEnvironment: target.legacy?.passSettings ?? false,
                    buildWorkingDirectory: target.legacy?.workingDirectory,
                    buildPhases: []
                )
            } else {
                targetObject = PBXNativeTarget(name: target.name, buildPhases: [])
            }

            targetObjects[target.name] = addObject(targetObject)

            var explicitFileType: String?
            var lastKnownFileType: String?
            let fileType = Xcode.fileType(path: Path(target.filename))
            if target.platform == .macOS || target.platform == .watchOS || target.type == .framework {
                explicitFileType = fileType
            } else {
                lastKnownFileType = fileType
            }

            if !target.isLegacy {
                let fileReference = addObject(
                    PBXFileReference(
                        sourceTree: .buildProductsDir,
                        explicitFileType: explicitFileType,
                        lastKnownFileType: lastKnownFileType,
                        path: target.filename,
                        includeInIndex: false
                    ),
                    context: target.name
                )

                targetFileReferences[target.name] = fileReference
            }
        }

        for target in project.aggregateTargets {

            let aggregateTarget = addObject(
                PBXAggregateTarget(
                    name: target.name,
                    productName: target.name
                )
            )
            targetAggregateObjects[target.name] = aggregateTarget
        }

        for (name, package) in project.packages {
            let packageReference = XCRemoteSwiftPackageReference(repositoryURL: package.url, versionRequirement: package.versionRequirement)
            packageReferences[name] = packageReference
            addObject(packageReference)
        }

        try project.targets.forEach(generateTarget)
        try project.aggregateTargets.forEach(generateAggregateTarget)

        let productGroup = addObject(
            PBXGroup(
                children: targetFileReferences.valueArray,
                sourceTree: .group,
                name: "Products"
            )
        )
        derivedGroups.append(productGroup)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, files) in carthageFrameworksByPlatform {
                let platformGroup: PBXGroup = addObject(
                    PBXGroup(
                        children: files.sorted { $0.nameOrPath < $1.nameOrPath },
                        sourceTree: .group,
                        path: platform
                    )
                )
                platforms.append(platformGroup)
            }
            let carthageGroup = addObject(
                PBXGroup(
                    children: platforms,
                    sourceTree: .group,
                    name: "Carthage",
                    path: carthageResolver.buildPath
                )
            )
            frameworkFiles.append(carthageGroup)
        }

        if !frameworkFiles.isEmpty {
            let group = addObject(
                PBXGroup(
                    children: frameworkFiles,
                    sourceTree: .group,
                    name: "Frameworks"
                )
            )
            derivedGroups.append(group)
        }

        mainGroup.children = Array(sourceGenerator.rootGroups)
        sortGroups(group: mainGroup)
        // add derived groups at the end
        derivedGroups.forEach(sortGroups)
        mainGroup.children += derivedGroups
            .sorted { $0.nameOrPath.localizedStandardCompare($1.nameOrPath) == .orderedAscending }
            .map { $0 }

        let projectAttributes: [String: Any] = ["LastUpgradeCheck": project.xcodeVersion]
            .merged(project.attributes)

        let knownRegions = sourceGenerator.knownRegions.sorted()
        pbxProject.knownRegions = knownRegions.isEmpty ? ["en"] : knownRegions
        pbxProject.packages = packageReferences.sorted { $0.key < $1.key }.map { $1 }

        let allTargets: [PBXTarget] = targetObjects.valueArray + targetAggregateObjects.valueArray
        pbxProject.targets = allTargets
            .sorted { $0.name < $1.name }
        pbxProject.attributes = projectAttributes
        pbxProject.targetAttributes = generateTargetAttributes()
        return pbxProj
    }

    func generateAggregateTarget(_ target: AggregateTarget) throws {

        let aggregateTarget = targetAggregateObjects[target.name]!

        let configs: [XCBuildConfiguration] = project.configs.map { config in

            let buildSettings = project.getBuildSettings(settings: target.settings, config: config)

            var baseConfiguration: PBXFileReference?
            if let configPath = target.configFiles[config.name] {
                baseConfiguration = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference
            }
            let buildConfig = XCBuildConfiguration(
                name: config.name,
                baseConfiguration: baseConfiguration,
                buildSettings: buildSettings
            )
            return addObject(buildConfig)
        }

        let dependencies = target.targets.map { generateTargetDependency(from: target.name, to: $0) }

        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: ""
        ))

        var buildPhases: [PBXBuildPhase] = []
        buildPhases += try target.buildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        aggregateTarget.buildPhases = buildPhases
        aggregateTarget.buildConfigurationList = buildConfigList
        aggregateTarget.dependencies = dependencies
    }

    func generateTargetDependency(from: String, to target: String) -> PBXTargetDependency {
        guard let targetObject = targetObjects[target] ?? targetAggregateObjects[target] else {
            fatalError("target not found")
        }

        let targetProxy = addObject(
            PBXContainerItemProxy(
                containerPortal: .project(pbxProj.rootObject!),
                remoteGlobalID: .object(targetObject),
                proxyType: .nativeTarget,
                remoteInfo: target
            )
        )

        let targetDependency = addObject(
            PBXTargetDependency(
                target: targetObject,
                targetProxy: targetProxy
            )
        )
        return targetDependency
    }

    func generateBuildScript(targetName: String, buildScript: BuildScript) throws -> PBXShellScriptBuildPhase {

        let shellScript: String
        switch buildScript.script {
        case let .path(path):
            shellScript = try (project.basePath + path).read()
        case let .script(script):
            shellScript = script
        }

        let shellScriptPhase = PBXShellScriptBuildPhase(
            name: buildScript.name ?? "Run Script",
            inputPaths: buildScript.inputFiles,
            outputPaths: buildScript.outputFiles,
            inputFileListPaths: buildScript.inputFileLists,
            outputFileListPaths: buildScript.outputFileLists,
            shellPath: buildScript.shell ?? "/bin/sh",
            shellScript: shellScript,
            runOnlyForDeploymentPostprocessing: buildScript.runOnlyWhenInstalling,
            showEnvVarsInLog: buildScript.showEnvVars
        )
        return addObject(shellScriptPhase)
    }

    func generateCopyFiles(targetName: String, copyFiles: TargetSource.BuildPhase.CopyFilesSettings, buildPhaseFiles: [PBXBuildFile]) -> PBXCopyFilesBuildPhase {
        let copyFilesBuildPhase = PBXCopyFilesBuildPhase(
            dstPath: copyFiles.subpath,
            dstSubfolderSpec: copyFiles.destination.destination,
            files: buildPhaseFiles
        )
        return addObject(copyFilesBuildPhase)
    }

    func generateTargetAttributes() -> [PBXTarget: [String: Any]] {

        var targetAttributes: [PBXTarget: [String: Any]] = [:]

        let testTargets = pbxProj.nativeTargets.filter { $0.productType == .uiTestBundle || $0.productType == .unitTestBundle }
        for testTarget in testTargets {

            // look up TEST_TARGET_NAME build setting
            func testTargetName(_ target: PBXTarget) -> String? {
                guard let buildConfigurations = target.buildConfigurationList?.buildConfigurations else { return nil }

                return buildConfigurations
                    .compactMap { $0.buildSettings["TEST_TARGET_NAME"] as? String }
                    .first
            }

            guard let name = testTargetName(testTarget) else { continue }
            guard let target = self.pbxProj.targets(named: name).first else { continue }

            targetAttributes[testTarget, default: [:]].merge(["TestTargetID": target])
        }

        func generateTargetAttributes(_ target: ProjectTarget, pbxTarget: PBXTarget) {
            if !target.attributes.isEmpty {
                targetAttributes[pbxTarget, default: [:]].merge(target.attributes)
            }

            func getSingleBuildSetting(_ setting: String) -> String? {
                let settings = project.configs.compactMap {
                    project.getCombinedBuildSetting(setting, target: target, config: $0) as? String
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
                    targetAttributes[pbxTarget, default: [:]].merge([attribute: setting])
                }
            }

            setTargetAttribute(attribute: "ProvisioningStyle", buildSetting: "CODE_SIGN_STYLE")
            setTargetAttribute(attribute: "DevelopmentTeam", buildSetting: "DEVELOPMENT_TEAM")
        }

        for target in project.aggregateTargets {
            guard let pbxTarget = targetAggregateObjects[target.name] else {
                continue
            }
            generateTargetAttributes(target, pbxTarget: pbxTarget)
        }

        for target in project.targets {
            guard let pbxTarget = targetObjects[target.name] else {
                continue
            }
            generateTargetAttributes(target, pbxTarget: pbxTarget)
        }

        return targetAttributes
    }

    func sortGroups(group: PBXGroup) {
        // sort children
        let children = group.children
            .sorted { child1, child2 in
                let sortOrder1 = child1.getSortOrder(groupSortPosition: project.options.groupSortPosition)
                let sortOrder2 = child2.getSortOrder(groupSortPosition: project.options.groupSortPosition)

                if sortOrder1 != sortOrder2 {
                    return sortOrder1 < sortOrder2
                } else {
                    if child1.nameOrPath != child2.nameOrPath {
                        return child1.nameOrPath.localizedStandardCompare(child2.nameOrPath) == .orderedAscending
                    } else {
                        return child1.context ?? "" < child2.context ?? ""
                    }
                }
            }
        group.children = children.filter { $0 != group }

        // sort sub groups
        let childGroups = group.children.compactMap { $0 as? PBXGroup }
        childGroups.forEach(sortGroups)
    }

    func generateTarget(_ target: Target) throws {
        let carthageDependencies = carthageResolver.dependencies(for: target)

        let sourceFiles = try sourceGenerator.getAllSourceFiles(targetType: target.type, sources: target.sources)
            .sorted { $0.path.lastComponent < $1.path.lastComponent }

        var plistPath: Path?
        var searchForPlist = true
        var anyDependencyRequiresObjCLinking = false

        var dependencies: [PBXTargetDependency] = []
        var targetFrameworkBuildFiles: [PBXBuildFile] = []
        var frameworkBuildPaths = Set<String>()
        var copyFilesBuildPhasesFiles: [TargetSource.BuildPhase.CopyFilesSettings: [PBXBuildFile]] = [:]
        var copyFrameworksReferences: [PBXBuildFile] = []
        var copyResourcesReferences: [PBXBuildFile] = []
        var copyWatchReferences: [PBXBuildFile] = []
        var packageDependencies: [XCSwiftPackageProductDependency] = []
        var extensions: [PBXBuildFile] = []
        var carthageFrameworksToEmbed: [String] = []

        let targetDependencies = (target.transitivelyLinkDependencies ?? project.options.transitivelyLinkDependencies) ?
            getAllDependenciesPlusTransitiveNeedingEmbedding(target: target) : target.dependencies

        let targetSupportsDirectEmbed = !(target.platform.requiresSimulatorStripping &&
            (target.type.isApp || target.type == .watch2Extension))
        let directlyEmbedCarthage = target.directlyEmbedCarthageDependencies ?? targetSupportsDirectEmbed

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

        func getDependencyFrameworkSettings(dependency: Dependency) -> [String: Any]? {
            var linkingAttributes: [String] = []
            if dependency.weakLink {
                linkingAttributes.append("Weak")
            }
            return !linkingAttributes.isEmpty ? ["ATTRIBUTES": linkingAttributes] : nil
        }
        
        func isStaticDependency(for carthageDependency: Dependency) -> Bool {
            switch carthageDependency.type {
            case .carthage(_, let isStatic):
                return isStatic
            default:
                fatalError("Passed dependency should be Carthage dependency")
            }
        }

        for dependency in targetDependencies {

            let embed = dependency.embed ?? target.shouldEmbedDependencies

            switch dependency.type {
            case .target:
                let dependencyTargetName = dependency.reference
                let targetDependency = generateTargetDependency(from: target.name, to: dependencyTargetName)
                dependencies.append(targetDependency)

                guard let dependencyTarget = project.getTarget(dependencyTargetName) else { continue }

                let dependecyLinkage = dependencyTarget.defaultLinkage
                let link = dependency.link ??
                    (dependecyLinkage == .dynamic && target.type != .staticLibrary) ||
                    (dependecyLinkage == .static && target.type.isExecutable)

                if link {
                    let dependencyFile = targetFileReferences[dependencyTarget.name]!
                    let buildFile = addObject(
                        PBXBuildFile(file: dependencyFile, settings: getDependencyFrameworkSettings(dependency: dependency))
                    )
                    targetFrameworkBuildFiles.append(buildFile)

                    if !anyDependencyRequiresObjCLinking
                        && dependencyTarget.requiresObjCLinking ?? (dependencyTarget.type == .staticLibrary) {
                        anyDependencyRequiresObjCLinking = true
                    }
                }

                let embed = dependency.embed ?? (!dependencyTarget.type.isLibrary && (
                    target.type.isApp
                        || (target.type.isTest && (dependencyTarget.type.isFramework || dependencyTarget.type == .bundle))
                ))
                if embed {
                    let embedFile = addObject(
                        PBXBuildFile(
                            file: targetFileReferences[dependencyTarget.name]!,
                            settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? !dependencyTarget.type.isExecutable)
                        )
                    )

                    if dependencyTarget.type.isExtension {
                        // embed app extension
                        extensions.append(embedFile)
                    } else if dependencyTarget.type.isFramework {
                        copyFrameworksReferences.append(embedFile)
                    } else if dependencyTarget.type.isApp && dependencyTarget.platform == .watchOS {
                        copyWatchReferences.append(embedFile)
                    } else if dependencyTarget.type == .xpcService {
                        copyFilesBuildPhasesFiles[.xpcServices, default: []].append(embedFile)
                    } else {
                        copyResourcesReferences.append(embedFile)
                    }
                }

            case .framework:
                let buildPath = Path(dependency.reference).parent().string.quoted
                frameworkBuildPaths.insert(buildPath)

                let fileReference: PBXFileElement
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

                if dependency.link ?? (target.type != .staticLibrary) {
                    let buildFile = addObject(
                        PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                    )

                    targetFrameworkBuildFiles.append(buildFile)
                }

                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let embedFile = addObject(
                        PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    copyFrameworksReferences.append(embedFile)
                }
            case .sdk(let root):

                var dependencyPath = Path(dependency.reference)
                if !dependency.reference.contains("/") {
                    switch dependencyPath.extension ?? "" {
                    case "framework":
                        dependencyPath = Path("System/Library/Frameworks") + dependencyPath
                    case "tbd":
                        dependencyPath = Path("usr/lib") + dependencyPath
                    case "dylib":
                        dependencyPath = Path("usr/lib") + dependencyPath
                    default: break
                    }
                }

                let fileReference: PBXFileReference
                if let existingFileReferences = sdkFileReferences[dependency.reference] {
                    fileReference = existingFileReferences
                } else {
                    let sourceTree: PBXSourceTree
                    if let root = root {
                        sourceTree = .custom(root)
                    } else {
                        sourceTree = .sdkRoot
                    }
                    fileReference = addObject(
                        PBXFileReference(
                            sourceTree: sourceTree,
                            name: dependencyPath.lastComponent,
                            lastKnownFileType: Xcode.fileType(path: dependencyPath),
                            path: dependencyPath.string
                        )
                    )
                    sdkFileReferences[dependency.reference] = fileReference
                    frameworkFiles.append(fileReference)
                }

                let buildFile = addObject(
                    PBXBuildFile(
                        file: fileReference,
                        settings: getDependencyFrameworkSettings(dependency: dependency)
                    )
                )
                targetFrameworkBuildFiles.append(buildFile)

            case .carthage(let findFrameworks, let isStatic):
                let findFrameworks = findFrameworks ?? project.options.findCarthageFrameworks
                let isStatic = isStatic
                let allDependencies = findFrameworks
                    ? carthageResolver.relatedDependencies(for: dependency, in: target.platform) : [dependency]
                allDependencies.forEach { dependency in

                    var platformPath = Path(carthageResolver.buildPath(for: target.platform, isStatic: isStatic))
                    var frameworkPath = platformPath + dependency.reference
                    if frameworkPath.extension == nil {
                        frameworkPath = Path(frameworkPath.string + ".framework")
                    }
                    let fileReference = self.sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                    self.carthageFrameworksByPlatform[target.platform.carthageName, default: []].insert(fileReference)
                    
                    if dependency.link ?? (target.type != .staticLibrary) {
                        let buildFile = self.addObject(
                            PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                        )
                        targetFrameworkBuildFiles.append(buildFile)
                    }
                }
            // Embedding handled by iterating over `carthageDependencies` below
            case .package(let product):
                guard let packageReference = packageReferences[dependency.reference] else {
                    return
                }

                let productName = product ?? dependency.reference
                let packageDependency = addObject(
                    XCSwiftPackageProductDependency(productName: productName, package: packageReference)
                )
                packageDependencies.append(packageDependency)

                let link = dependency.link ?? (target.type != .staticLibrary)
                if link {
                    let buildFile = addObject(
                        PBXBuildFile(product: packageDependency)
                    )
                    targetFrameworkBuildFiles.append(buildFile)
                }

                let targetDependency = addObject(
                    PBXTargetDependency(product: packageDependency)
                )
                dependencies.append(targetDependency)
            }
        }

        for dependency in carthageDependencies {
            
            let embed = dependency.embed ?? target.shouldEmbedCarthageDependencies

            var platformPath = Path(carthageResolver.buildPath(for: target.platform, isStatic: isStaticDependency(for: dependency)))
            var frameworkPath = platformPath + dependency.reference
            if frameworkPath.extension == nil {
                frameworkPath = Path(frameworkPath.string + ".framework")
            }
            let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

            if embed && !isStaticDependency(for: dependency) {
                if directlyEmbedCarthage {
                    let embedFile = addObject(
                        PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    copyFrameworksReferences.append(embedFile)
                } else {
                    carthageFrameworksToEmbed.append(dependency.reference)
                }
            } else if isStaticDependency(for: dependency) {
                let embedFile = addObject(
                    PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                )
                targetFrameworkBuildFiles.append(embedFile)
            }
        }

        var buildPhases: [PBXBuildPhase] = []

        func getBuildFilesForSourceFiles(_ sourceFiles: [SourceFile]) -> [PBXBuildFile] {
            return sourceFiles
                .reduce(into: [SourceFile]()) { output, sourceFile in
                    if !output.contains(where: { $0.fileReference === sourceFile.fileReference }) {
                        output.append(sourceFile)
                    }
                }
                .map { addObject($0.buildFile) }
        }

        func getBuildFilesForPhase(_ buildPhase: BuildPhase) -> [PBXBuildFile] {
            let filteredSourceFiles = sourceFiles
                .filter { $0.buildPhase?.buildPhase == buildPhase }
            return getBuildFilesForSourceFiles(filteredSourceFiles)
        }

        func getBuildFilesForCopyFilesPhases() -> [TargetSource.BuildPhase.CopyFilesSettings: [PBXBuildFile]] {
            var sourceFilesByCopyFiles: [TargetSource.BuildPhase.CopyFilesSettings: [SourceFile]] = [:]
            for sourceFile in sourceFiles {
                guard case let .copyFiles(copyFilesSettings)? = sourceFile.buildPhase else { continue }
                sourceFilesByCopyFiles[copyFilesSettings, default: []].append(sourceFile)
            }
            return sourceFilesByCopyFiles.mapValues { getBuildFilesForSourceFiles($0) }
        }

        copyFilesBuildPhasesFiles.merge(getBuildFilesForCopyFilesPhases()) { $0 + $1 }

        buildPhases += try target.preBuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        buildPhases += copyFilesBuildPhasesFiles
            .filter { $0.key.phaseOrder == .preCompile }
            .map { generateCopyFiles(targetName: target.name, copyFiles: $0, buildPhaseFiles: $1) }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers)
        if !headersBuildPhaseFiles.isEmpty {
            if target.type == .framework || target.type == .dynamicLibrary {
                let headersBuildPhase = addObject(PBXHeadersBuildPhase(files: headersBuildPhaseFiles))
                buildPhases.append(headersBuildPhase)
            } else {
                headersBuildPhaseFiles.forEach { pbxProj.delete(object: $0) }
            }
        }

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        // Sticker packs should not include a compile sources build phase as they
        // are purely based on a set of image files, and nothing else.
        let shouldSkipSourcesBuildPhase = sourcesBuildPhaseFiles.isEmpty && target.type == .stickerPack
        if !shouldSkipSourcesBuildPhase {
            let sourcesBuildPhase = addObject(PBXSourcesBuildPhase(files: sourcesBuildPhaseFiles))
            buildPhases.append(sourcesBuildPhase)
        }

        buildPhases += try target.postCompileScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        let resourcesBuildPhaseFiles = getBuildFilesForPhase(.resources) + copyResourcesReferences
        if !resourcesBuildPhaseFiles.isEmpty {
            let resourcesBuildPhase = addObject(PBXResourcesBuildPhase(files: resourcesBuildPhaseFiles))
            buildPhases.append(resourcesBuildPhase)
        }

        let swiftObjCInterfaceHeader = project.getCombinedBuildSetting("SWIFT_OBJC_INTERFACE_HEADER_NAME", target: target, config: project.configs[0]) as? String

        if target.type == .staticLibrary
            && swiftObjCInterfaceHeader != ""
            && sourceFiles.contains(where: { $0.buildPhase == .sources && $0.path.extension == "swift" }) {

            let inputPaths = ["$(DERIVED_SOURCES_DIR)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"]
            let outputPaths = ["$(BUILT_PRODUCTS_DIR)/include/$(PRODUCT_MODULE_NAME)/$(SWIFT_OBJC_INTERFACE_HEADER_NAME)"]
            let script = addObject(
                PBXShellScriptBuildPhase(
                    name: "Copy Swift Objective-C Interface Header",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh",
                    shellScript: "ditto \"${SCRIPT_INPUT_FILE_0}\" \"${SCRIPT_OUTPUT_FILE_0}\"\n"
                )
            )
            buildPhases.append(script)
        }

        buildPhases += copyFilesBuildPhasesFiles
            .filter { $0.key.phaseOrder == .postCompile }
            .map { generateCopyFiles(targetName: target.name, copyFiles: $0, buildPhaseFiles: $1) }

        if !carthageFrameworksToEmbed.isEmpty {

            let inputPaths = carthageFrameworksToEmbed
                .map { "$(SRCROOT)/\(carthageResolver.buildPath(for: target.platform, isStatic: false))/\($0)\($0.contains(".") ? "" : ".framework")" }
            let outputPaths = carthageFrameworksToEmbed
                .map { "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")" }
            let carthageExecutable = carthageResolver.executable
            let carthageScript = addObject(
                PBXShellScriptBuildPhase(
                    name: "Carthage",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh",
                    shellScript: "\(carthageExecutable) copy-frameworks\n"
                )
            )
            buildPhases.append(carthageScript)
        }

        if !targetFrameworkBuildFiles.isEmpty {

            let frameworkBuildPhase = addObject(
                PBXFrameworksBuildPhase(files: targetFrameworkBuildFiles)
            )
            buildPhases.append(frameworkBuildPhase)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = addObject(
                PBXCopyFilesBuildPhase(
                    dstPath: "",
                    dstSubfolderSpec: .plugins,
                    name: "Embed App Extensions",
                    files: extensions
                )
            )

            buildPhases.append(copyFilesPhase)
        }

        copyFrameworksReferences += getBuildFilesForPhase(.frameworks)
        if !copyFrameworksReferences.isEmpty {

            let copyFilesPhase = addObject(
                PBXCopyFilesBuildPhase(
                    dstPath: "",
                    dstSubfolderSpec: .frameworks,
                    name: "Embed Frameworks",
                    files: copyFrameworksReferences
                )
            )

            buildPhases.append(copyFilesPhase)
        }

        if !copyWatchReferences.isEmpty {

            let copyFilesPhase = addObject(
                PBXCopyFilesBuildPhase(
                    dstPath: "$(CONTENTS_FOLDER_PATH)/Watch",
                    dstSubfolderSpec: .productsDirectory,
                    name: "Embed Watch Content",
                    files: copyWatchReferences
                )
            )

            buildPhases.append(copyFilesPhase)
        }

        let buildRules = target.buildRules.map { buildRule in
            addObject(
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
            )
        }

        buildPhases += try target.postBuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        let configs: [XCBuildConfiguration] = project.configs.map { config in
            var buildSettings = project.getTargetBuildSettings(target: target, config: config)

            // Set CODE_SIGN_ENTITLEMENTS
            if let entitlements = target.entitlements {
                buildSettings["CODE_SIGN_ENTITLEMENTS"] = entitlements.path
            }

            // Set INFOPLIST_FILE if not defined in settings
            if !project.targetHasBuildSetting("INFOPLIST_FILE", target: target, config: config) {
                if let info = target.info {
                    buildSettings["INFOPLIST_FILE"] = info.path
                } else if searchForPlist {
                    plistPath = getInfoPlist(target.sources)
                    searchForPlist = false
                }
                if let plistPath = plistPath {
                    buildSettings["INFOPLIST_FILE"] = (try? plistPath.relativePath(from: projectDirectory ?? project.basePath)) ?? plistPath
                }
            }

            // automatically calculate bundle id
            if let bundleIdPrefix = project.options.bundleIdPrefix,
                !project.targetHasBuildSetting("PRODUCT_BUNDLE_IDENTIFIER", target: target, config: config) {
                let characterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-.")).inverted
                let escapedTargetName = target.name
                    .replacingOccurrences(of: "_", with: "-")
                    .components(separatedBy: characterSet)
                    .joined(separator: "")
                buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] = bundleIdPrefix + "." + escapedTargetName
            }

            // automatically set test target name
            if target.type == .uiTestBundle || target.type == .unitTestBundle,
                !project.targetHasBuildSetting("TEST_TARGET_NAME", target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                        let dependencyTarget = project.getTarget(dependency.reference),
                        dependencyTarget.type.isApp {
                        buildSettings["TEST_TARGET_NAME"] = dependencyTarget.name
                        break
                    }
                }
            }

            // automatically set TEST_HOST
            if target.type == .unitTestBundle,
                !project.targetHasBuildSetting("TEST_HOST", target: target, config: config) {
                for dependency in target.dependencies {
                    if dependency.type == .target,
                        let dependencyTarget = project.getTarget(dependency.reference),
                        dependencyTarget.type.isApp {
                        if dependencyTarget.platform == .macOS {
                            buildSettings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/\(dependencyTarget.productName).app/Contents/MacOS/\(dependencyTarget.productName)"
                        } else {
                            buildSettings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/\(dependencyTarget.productName).app/\(dependencyTarget.productName)"
                        }
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
                var carthagePlatformBuildPaths: [String] = []
                if carthageDependencies.contains(where: { isStaticDependency(for: $0) }) {
                    let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, isStatic: true)
                    carthagePlatformBuildPaths.append(carthagePlatformBuildPath)
                }
                if carthageDependencies.contains(where: { !isStaticDependency(for: $0) }) {
                    let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, isStatic: false)
                    carthagePlatformBuildPaths.append(carthagePlatformBuildPath)
                }
                configFrameworkBuildPaths = carthagePlatformBuildPaths + frameworkBuildPaths.sorted()
            } else {
                configFrameworkBuildPaths = frameworkBuildPaths.sorted()
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

            var baseConfiguration: PBXFileReference?
            if let configPath = target.configFiles[config.name],
                let fileReference = sourceGenerator.getContainedFileReference(path: project.basePath + configPath) as? PBXFileReference {
                baseConfiguration = fileReference
            }
            let buildConfig = XCBuildConfiguration(
                name: config.name,
                buildSettings: buildSettings
            )
            buildConfig.baseConfiguration = baseConfiguration
            return addObject(buildConfig)
        }

        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: ""
        ))

        let targetObject = targetObjects[target.name]!

        let targetFileReference = targetFileReferences[target.name]

        targetObject.name = target.name
        targetObject.buildConfigurationList = buildConfigList
        targetObject.buildPhases = buildPhases
        targetObject.dependencies = dependencies
        targetObject.productName = target.name
        targetObject.buildRules = buildRules
        targetObject.packageProductDependencies = packageDependencies
        targetObject.product = targetFileReference
        if !target.isLegacy {
            targetObject.productType = target.type
        }
    }

    func getInfoPlist(_ sources: [TargetSource]) -> Path? {
        return sources
            .lazy
            .map { self.project.basePath + $0.path }
            .compactMap { (path) -> Path? in
                if path.isFile {
                    return path.lastComponent == "Info.plist" ? path : nil
                } else {
                    return path.first(where: { $0.lastComponent == "Info.plist" })
                }
            }
            .first
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
                if dependencies[dependency.reference] != nil {
                    continue
                }

                // don't want a dependency if it's going to be embedded or statically linked in a non-top level target
                // in .target check we filter out targets that will embed all of their dependencies
                switch dependency.type {
                case .sdk:
                    dependencies[dependency.reference] = dependency
                case .framework, .carthage, .package:
                    if isTopLevel || dependency.embed == nil {
                        dependencies[dependency.reference] = dependency
                    }
                case .target:
                    if isTopLevel || dependency.embed == nil {
                        if let dependencyTarget = project.getTarget(dependency.reference) {
                            dependencies[dependency.reference] = dependency
                            if !dependencyTarget.shouldEmbedDependencies {
                                // traverse target's dependencies if it doesn't embed them itself
                                queue.append(dependencyTarget)
                            }
                        } else if project.getAggregateTarget(dependency.reference) != nil {
                            // Aggregate targets should be included
                            dependencies[dependency.reference] = dependency
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

    var shouldEmbedCarthageDependencies: Bool {
        return (type.isApp && platform != .watchOS)
            || type == .watch2Extension
            || type.isTest
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
