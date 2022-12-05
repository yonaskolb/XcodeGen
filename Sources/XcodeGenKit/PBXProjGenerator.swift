import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import Yams
import Version

public class PBXProjGenerator {

    let project: Project

    let pbxProj: PBXProj
    let projectDirectory: Path?
    let carthageResolver: CarthageDependencyResolver

    public static let copyFilesActionMask: UInt = 8

    var sourceGenerator: SourceGenerator!

    var targetObjects: [String: PBXTarget] = [:]
    var targetAggregateObjects: [String: PBXAggregateTarget] = [:]
    var targetFileReferences: [String: PBXFileReference] = [:]
    var sdkFileReferences: [String: PBXFileReference] = [:]
    var packageReferences: [String: XCRemoteSwiftPackageReference] = [:]

    var carthageFrameworksByPlatform: [String: Set<PBXFileElement>] = [:]
    var frameworkFiles: [PBXFileElement] = []
    var bundleFiles: [PBXFileElement] = []

    var generated = false

    private var projects: [ProjectReference: PBXProj] = [:]

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

        let developmentRegion = project.options.developmentLanguage ?? "en"
        let pbxProject = addObject(
            PBXProject(
                name: project.name,
                buildConfigurationList: buildConfigList,
                compatibilityVersion: project.compatibilityVersion,
                mainGroup: mainGroup,
                developmentRegion: developmentRegion
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
            let fileType = Xcode.fileType(path: Path(target.filename), productType: target.type)
            if target.platform == .macOS || target.platform == .watchOS || target.type == .framework || target.type == .extensionKitExtension {
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
            switch package {
            case let .remote(url, versionRequirement):
                let packageReference = XCRemoteSwiftPackageReference(repositoryURL: url, versionRequirement: versionRequirement)
                packageReferences[name] = packageReference
                addObject(packageReference)
            case let .local(path, group):
                try sourceGenerator.createLocalPackage(path: Path(path), group: group.map { Path($0) })
            }
        }

        let productGroup = addObject(
            PBXGroup(
                children: targetFileReferences.valueArray,
                sourceTree: .group,
                name: "Products"
            )
        )
        derivedGroups.append(productGroup)

        let sortedProjectReferences = project.projectReferences.sorted { $0.name < $1.name }
        let subprojectFileReferences: [PBXFileReference] = sortedProjectReferences.map { projectReference in
            let projectPath = Path(projectReference.path)

            return addObject(
                PBXFileReference(
                    sourceTree: .group,
                    name: projectReference.name,
                    lastKnownFileType: Xcode.fileType(path: projectPath),
                    path: projectPath.normalize().string
                )
            )
        }
        if subprojectFileReferences.count > 0 {
            let subprojectsGroups = addObject(
                PBXGroup(
                    children: subprojectFileReferences,
                    sourceTree: .group,
                    name: "Projects"
                )
            )
            derivedGroups.append(subprojectsGroups)

            let subprojects: [[String: PBXFileElement]] = subprojectFileReferences.map { projectReference in
                let group = addObject(
                    PBXGroup(
                        children: [],
                        sourceTree: .group,
                        name: "Products"
                    )
                )
                return [
                    "ProductGroup": group,
                    "ProjectRef": projectReference,
                ]
            }

            pbxProject.projects = subprojects
        }

        let pbxVariantGroupInfoList = try PBXVariantGroupGenerator(pbxProj: pbxProj, project: project).generate()
        try project.targets.forEach { try generateTarget($0, pbxVariantGroupInfoList: pbxVariantGroupInfoList) }
        try project.aggregateTargets.forEach(generateAggregateTarget)

        if !carthageFrameworksByPlatform.isEmpty {
            var platforms: [PBXGroup] = []
            for (platform, files) in carthageFrameworksByPlatform {
                let platformGroup: PBXGroup = addObject(
                    PBXGroup(
                        children: Array(files),
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

        if !bundleFiles.isEmpty {
            let group = addObject(
                PBXGroup(
                    children: bundleFiles,
                    sourceTree: .group,
                    name: "Bundles"
                )
            )
            derivedGroups.append(group)
        }

        mainGroup.children = Array(sourceGenerator.rootGroups)
        sortGroups(group: mainGroup)
        setupGroupOrdering(group: mainGroup)
        // add derived groups at the end
        derivedGroups.forEach(sortGroups)
        mainGroup.children += derivedGroups
            .sorted(by: PBXFileElement.sortByNamePath)
            .map { $0 }

        let assetTags = Set(project.targets
            .map { target in
                target.sources.map { $0.resourceTags }.flatMap { $0 }
            }.flatMap { $0 }
        ).sorted()

        var projectAttributes: [String: Any] = project.attributes
        
        // Set default LastUpgradeCheck if user did not specify
        let lastUpgradeKey = "LastUpgradeCheck"
        if !projectAttributes.contains(where: { (key, value) -> Bool in
            key == lastUpgradeKey && value is String
        }) {
            projectAttributes[lastUpgradeKey] = project.xcodeVersion
        }
        
        if !assetTags.isEmpty {
            projectAttributes["knownAssetTags"] = assetTags
        }

        var knownRegions = Set(sourceGenerator.knownRegions)
        knownRegions.insert(developmentRegion)
        if project.options.useBaseInternationalization {
            knownRegions.insert("Base")
        }
        pbxProject.knownRegions = knownRegions.sorted()

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

        let dependencies = target.targets.map { generateTargetDependency(from: target.name, to: $0, platform: nil) }

        let defaultConfigurationName = project.options.defaultConfig ?? project.configs.first?.name ?? ""
        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: defaultConfigurationName
        ))

        var buildPhases: [PBXBuildPhase] = []
        buildPhases += try target.buildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        aggregateTarget.buildPhases = buildPhases
        aggregateTarget.buildConfigurationList = buildConfigList
        aggregateTarget.dependencies = dependencies
    }

    func generateTargetDependency(from: String, to target: String, platform: String?) -> PBXTargetDependency {
        guard let targetObject = targetObjects[target] ?? targetAggregateObjects[target] else {
            fatalError("Target dependency not found: from ( \(from) ) to ( \(target) )")
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
                platformFilter: platform,
                target: targetObject,
                targetProxy: targetProxy
            )
        )
        return targetDependency
    }

    func generateExternalTargetDependency(from: String, to target: String, in project: String, platform: Platform) throws -> (PBXTargetDependency, Target, PBXReferenceProxy) {
        guard let projectReference = self.project.getProjectReference(project) else {
            fatalError("project '\(project)' not found")
        }

        let pbxProj = try getPBXProj(from: projectReference)

        guard let targetObject = pbxProj.targets(named: target).first else {
            fatalError("target '\(target)' not found in project '\(project)'")
        }

        let projectFileReferenceIndex = self.pbxProj.rootObject!
            .projects
            .map { $0["ProjectRef"] as? PBXFileReference }
            .firstIndex { $0?.path == Path(projectReference.path).normalize().string }

        guard let index = projectFileReferenceIndex,
            let projectFileReference = self.pbxProj.rootObject?.projects[index]["ProjectRef"] as? PBXFileReference,
            let productsGroup = self.pbxProj.rootObject?.projects[index]["ProductGroup"] as? PBXGroup else {
            fatalError("Missing subproject file reference")
        }

        let targetProxy = addObject(
            PBXContainerItemProxy(
                containerPortal: .fileReference(projectFileReference),
                remoteGlobalID: .object(targetObject),
                proxyType: .nativeTarget,
                remoteInfo: target
            )
        )

        let productProxy = addObject(
            PBXContainerItemProxy(
                containerPortal: .fileReference(projectFileReference),
                remoteGlobalID: targetObject.product.flatMap(PBXContainerItemProxy.RemoteGlobalID.object),
                proxyType: .reference,
                remoteInfo: target
            )
        )

        var path = targetObject.productNameWithExtension()

        if targetObject.productType == .staticLibrary,
            let tmpPath = path, !tmpPath.hasPrefix("lib") {
            path = "lib\(tmpPath)"
        }

        let productReferenceProxy = addObject(
            PBXReferenceProxy(
                fileType: targetObject.productNameWithExtension().flatMap { Xcode.fileType(path: Path($0)) },
                path: path,
                remote: productProxy,
                sourceTree: .buildProductsDir
            )
        )

        productsGroup.children.append(productReferenceProxy)

        let targetDependency = addObject(
            PBXTargetDependency(
                name: targetObject.name,
                targetProxy: targetProxy
            )
        )

        guard let buildConfigurations = targetObject.buildConfigurationList?.buildConfigurations,
            let defaultConfigurationName = targetObject.buildConfigurationList?.defaultConfigurationName,
            let defaultConfiguration = buildConfigurations.first(where: { $0.name == defaultConfigurationName }) ?? buildConfigurations.first else {

            fatalError("Missing target info")
        }

        let productType: PBXProductType = targetObject.productType ?? .none
        let buildSettings = defaultConfiguration.buildSettings
        let settings = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
        let deploymentTargetString = buildSettings[platform.deploymentTargetSetting] as? String
        let deploymentTarget = deploymentTargetString == nil ? nil : try Version.parse(deploymentTargetString!)
        let requiresObjCLinking = (buildSettings["OTHER_LDFLAGS"] as? String)?.contains("-ObjC") ?? (productType == .staticLibrary)
        let dependencyTarget = Target(
            name: targetObject.name,
            type: productType,
            platform: platform,
            productName: targetObject.productName,
            deploymentTarget: deploymentTarget,
            settings: settings,
            requiresObjCLinking: requiresObjCLinking
        )

        return (targetDependency, dependencyTarget, productReferenceProxy)
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
            showEnvVarsInLog: buildScript.showEnvVars,
            alwaysOutOfDate: !buildScript.basedOnDependencyAnalysis,
            dependencyFile: buildScript.discoveredDependencyFile
        )
        return addObject(shellScriptPhase)
    }

    func generateCopyFiles(targetName: String, copyFiles: BuildPhaseSpec.CopyFilesSettings, buildPhaseFiles: [PBXBuildFile]) -> PBXCopyFilesBuildPhase {
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
                    if (child1.name, child1.path) != (child2.name, child2.path) {
                        return PBXFileElement.sortByNamePath(child1, child2)
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

    public func setupGroupOrdering(group: PBXGroup) {
        let groupOrdering = project.options.groupOrdering.first { groupOrdering in
            let groupName = group.nameOrPath

            if groupName == groupOrdering.pattern {
                return true
            }

            if let regex = groupOrdering.regex {
                return regex.isMatch(to: groupName)
            }

            return false
        }

        if let order = groupOrdering?.order {
            let files = group.children.filter { $0 is PBXFileReference }
            var groups = group.children.filter { $0 is PBXGroup }

            var filteredGroups = [PBXFileElement]()

            for groupName in order {
                guard let group = groups.first(where: { $0.nameOrPath == groupName }) else {
                    continue
                }

                filteredGroups.append(group)
                groups.removeAll { $0 == group }
            }

            filteredGroups += groups

            switch project.options.groupSortPosition {
            case .top:
                group.children = filteredGroups + files
            case .bottom:
                group.children = files + filteredGroups
            default:
                break
            }
        }

        // sort sub groups
        let childGroups = group.children.compactMap { $0 as? PBXGroup }
        childGroups.forEach(setupGroupOrdering)
    }

    func getPBXProj(from reference: ProjectReference) throws -> PBXProj {
        if let cachedProject = projects[reference] {
            return cachedProject
        }
        let pbxproj = try XcodeProj(pathString: (project.basePath + Path(reference.path).normalize()).string).pbxproj
        projects[reference] = pbxproj
        return pbxproj
    }

    func generateTarget(_ target: Target, pbxVariantGroupInfoList: [PBXVariantGroupInfo]) throws {
        let carthageDependencies = carthageResolver.dependencies(for: target)

        let infoPlistFiles: [Config: String] = getInfoPlists(for: target)
        let sourceFileBuildPhaseOverrideSequence: [(Path, BuildPhaseSpec)] = Set(infoPlistFiles.values).map({ (project.basePath + $0, .none) })
        let sourceFileBuildPhaseOverrides = Dictionary(uniqueKeysWithValues: sourceFileBuildPhaseOverrideSequence)
        let sourceFiles = try sourceGenerator.getAllSourceFiles(targetName: target.name, targetType: target.type, sources: target.sources, buildPhases: sourceFileBuildPhaseOverrides, pbxVariantGroupInfoList: pbxVariantGroupInfoList)
            .sorted { $0.path.lastComponent < $1.path.lastComponent }

        var anyDependencyRequiresObjCLinking = false

        var dependencies: [PBXTargetDependency] = []
        var targetFrameworkBuildFiles: [PBXBuildFile] = []
        var frameworkBuildPaths = Set<String>()
        var customCopyDependenciesReferences: [PBXBuildFile] = []
        var copyFilesBuildPhasesFiles: [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]] = [:]
        var copyFrameworksReferences: [PBXBuildFile] = []
        var copyResourcesReferences: [PBXBuildFile] = []
        var copyBundlesReferences: [PBXBuildFile] = []
        var copyWatchReferences: [PBXBuildFile] = []
        var packageDependencies: [XCSwiftPackageProductDependency] = []
        var extensions: [PBXBuildFile] = []
        var extensionKitExtensions: [PBXBuildFile] = []
        var systemExtensions: [PBXBuildFile] = []
        var appClips: [PBXBuildFile] = []
        var carthageFrameworksToEmbed: [String] = []
        let localPackageReferences: [String] = project.packages.compactMap { $0.value.isLocal ? $0.key : nil }

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
            var retval: [String:Any] = ["ATTRIBUTES": embedAttributes]
            if let copyPhase = dependency.copyPhase {
                retval["COPY_PHASE"] = copyPhase
            }
            return retval
        }

        func getDependencyFrameworkSettings(dependency: Dependency) -> [String: Any]? {
            var linkingAttributes: [String] = []
            if dependency.weakLink {
                linkingAttributes.append("Weak")
            }
            return !linkingAttributes.isEmpty ? ["ATTRIBUTES": linkingAttributes] : nil
        }

        func processTargetDependency(_ dependency: Dependency, dependencyTarget: Target, embedFileReference: PBXFileElement?, platform: String?) {
            let dependencyLinkage = dependencyTarget.defaultLinkage
            let link = dependency.link ??
                ((dependencyLinkage == .dynamic && target.type != .staticLibrary) ||
                    (dependencyLinkage == .static && target.type.isExecutable))

            if link, let dependencyFile = embedFileReference {
                let pbxBuildFile = PBXBuildFile(file: dependencyFile, settings: getDependencyFrameworkSettings(dependency: dependency))
                pbxBuildFile.platformFilter = platform
                let buildFile = addObject(pbxBuildFile)
                targetFrameworkBuildFiles.append(buildFile)

                if !anyDependencyRequiresObjCLinking
                    && dependencyTarget.requiresObjCLinking ?? (dependencyTarget.type == .staticLibrary) {
                    anyDependencyRequiresObjCLinking = true
                }
            }

            let embed = dependency.embed ?? target.type.shouldEmbed(dependencyTarget)
            if embed {
                let pbxBuildFile = PBXBuildFile(
                    file: embedFileReference,
                    settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? !dependencyTarget.type.isExecutable)
                )
                pbxBuildFile.platformFilter = platform
                let embedFile = addObject(pbxBuildFile)

                if dependency.copyPhase != nil {
                    // custom copy takes precedence
                    customCopyDependenciesReferences.append(embedFile)
                } else if dependencyTarget.type.isExtension {
                    if dependencyTarget.type == .extensionKitExtension {
                        // embed extension kit extension
                        extensionKitExtensions.append(embedFile)
                    } else {
                        // embed app extension
                        extensions.append(embedFile)
                    }
                } else if dependencyTarget.type.isSystemExtension {
                    // embed system extension
                    systemExtensions.append(embedFile)
                } else if dependencyTarget.type == .onDemandInstallCapableApplication {
                    // embed app clip
                    appClips.append(embedFile)
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
        }

        for dependency in targetDependencies {

            let embed = dependency.embed ?? target.shouldEmbedDependencies
            let platform = makePlatformFilter(for: dependency.platformFilter)
            
            switch dependency.type {
            case .target:
                let dependencyTargetReference = try TargetReference(dependency.reference)

                switch dependencyTargetReference.location {
                case .local:
                    let dependencyTargetName = dependency.reference
                    let targetDependency = generateTargetDependency(from: target.name, to: dependencyTargetName, platform: platform)
                    dependencies.append(targetDependency)
                    guard let dependencyTarget = project.getTarget(dependencyTargetName) else { continue }
                    processTargetDependency(dependency, dependencyTarget: dependencyTarget, embedFileReference: targetFileReferences[dependencyTarget.name], platform: platform)
                case .project(let dependencyProjectName):
                    let dependencyTargetName = dependencyTargetReference.name
                    let (targetDependency, dependencyTarget, dependencyProductProxy) = try generateExternalTargetDependency(from: target.name, to: dependencyTargetName, in: dependencyProjectName, platform: target.platform)
                    dependencies.append(targetDependency)
                    processTargetDependency(dependency, dependencyTarget: dependencyTarget, embedFileReference: dependencyProductProxy, platform: platform)
                }

            case .framework:
                if !dependency.implicit {
                    let buildPath = Path(dependency.reference).parent().string.quoted
                    frameworkBuildPaths.insert(buildPath)
                }

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
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                    pbxBuildFile.platformFilter = platform
                    let buildFile = addObject(pbxBuildFile)

                    targetFrameworkBuildFiles.append(buildFile)
                }

                if !frameworkFiles.contains(fileReference) {
                    frameworkFiles.append(fileReference)
                }

                if embed {
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    pbxBuildFile.platformFilter = platform
                    let embedFile = addObject(pbxBuildFile)
                    
                    if dependency.copyPhase != nil {
                        customCopyDependenciesReferences.append(embedFile)
                    } else {
                        copyFrameworksReferences.append(embedFile)
                    }
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

                let pbxBuildFile = PBXBuildFile(
                    file: fileReference,
                    settings: getDependencyFrameworkSettings(dependency: dependency)
                )
                pbxBuildFile.platformFilter = platform
                let buildFile = addObject(pbxBuildFile)
                targetFrameworkBuildFiles.append(buildFile)

                if dependency.embed == true {
                    let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    pbxBuildFile.platformFilter = platform
                    let embedFile = addObject(pbxBuildFile)
                    
                    if dependency.copyPhase != nil {
                        customCopyDependenciesReferences.append(embedFile)
                    } else {
                        copyFrameworksReferences.append(embedFile)
                    }
                }

            case .carthage(let findFrameworks, let linkType):
                let findFrameworks = findFrameworks ?? project.options.findCarthageFrameworks
                let allDependencies = findFrameworks
                    ? carthageResolver.relatedDependencies(for: dependency, in: target.platform) : [dependency]
                allDependencies.forEach { dependency in

                    let platformPath = Path(carthageResolver.buildPath(for: target.platform, linkType: linkType))
                    var frameworkPath = platformPath + dependency.reference
                    if frameworkPath.extension == nil {
                        frameworkPath = Path(frameworkPath.string + ".framework")
                    }
                    let fileReference = self.sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

                    self.carthageFrameworksByPlatform[target.platform.carthageName, default: []].insert(fileReference)

                    let isStaticLibrary = target.type == .staticLibrary
                    let isCarthageStaticLink = dependency.carthageLinkType == .static
                    if dependency.link ?? (!isStaticLibrary && !isCarthageStaticLink) {
                        let pbxBuildFile = PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                        pbxBuildFile.platformFilter = platform
                        let buildFile = addObject(pbxBuildFile)
                        targetFrameworkBuildFiles.append(buildFile)
                    }
                }
            // Embedding handled by iterating over `carthageDependencies` below
            case .package(let product):
                let packageReference = packageReferences[dependency.reference]

                // If package's reference is none and there is no specified package in localPackages,
                // then ignore the package specified as dependency.
                if packageReference == nil, !localPackageReferences.contains(dependency.reference) {
                    continue
                }

                let productName = product ?? dependency.reference
                let packageDependency = addObject(
                    XCSwiftPackageProductDependency(productName: productName, package: packageReference)
                )

                // Add package dependency if linking is true.
                if dependency.link ?? true {
                    packageDependencies.append(packageDependency)
                }

                let link = dependency.link ?? (target.type != .staticLibrary)
                if link {
                    let file = PBXBuildFile(product: packageDependency, settings: getDependencyFrameworkSettings(dependency: dependency))
                    file.platformFilter = platform
                    let buildFile = addObject(file)
                    targetFrameworkBuildFiles.append(buildFile)
                } else {
                    let targetDependency = addObject(
                        PBXTargetDependency(platformFilter: platform, product: packageDependency)
                    )
                    dependencies.append(targetDependency)
                }

                if dependency.embed == true {
                    let pbxBuildFile = PBXBuildFile(product: packageDependency,
                    settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    pbxBuildFile.platformFilter = platform
                    let embedFile = addObject(pbxBuildFile)
                    
                    if dependency.copyPhase != nil {
                        customCopyDependenciesReferences.append(embedFile)
                    } else {
                        copyFrameworksReferences.append(embedFile)
                    }
                }
            case .bundle:
                // Static and dynamic libraries can't copy resources
                guard target.type != .staticLibrary && target.type != .dynamicLibrary else { break }

                let fileReference = sourceGenerator.getFileReference(
                    path: Path(dependency.reference),
                    inPath: project.basePath,
                    sourceTree: .buildProductsDir
                )

                let pbxBuildFile = PBXBuildFile(
                    file: fileReference,
                    settings: embed ? getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true) : nil
                )
                pbxBuildFile.platformFilter = platform
                let buildFile = addObject(pbxBuildFile)
                copyBundlesReferences.append(buildFile)

                if !bundleFiles.contains(fileReference) {
                    bundleFiles.append(fileReference)
                }
            }
        }

        for carthageDependency in carthageDependencies {
            let dependency = carthageDependency.dependency
            let isFromTopLevelTarget = carthageDependency.isFromTopLevelTarget
            let embed = dependency.embed ?? target.shouldEmbedCarthageDependencies

            let platformPath = Path(carthageResolver.buildPath(for: target.platform, linkType: dependency.carthageLinkType ?? .default))
            var frameworkPath = platformPath + dependency.reference
            if frameworkPath.extension == nil {
                frameworkPath = Path(frameworkPath.string + ".framework")
            }
            let fileReference = sourceGenerator.getFileReference(path: frameworkPath, inPath: platformPath)

            if dependency.carthageLinkType == .static {
                guard isFromTopLevelTarget else { continue } // ignore transitive dependencies if static
                let linkFile = addObject(
                    PBXBuildFile(file: fileReference, settings: getDependencyFrameworkSettings(dependency: dependency))
                )
                targetFrameworkBuildFiles.append(linkFile)
            } else if embed {
                if directlyEmbedCarthage {
                    let embedFile = addObject(
                        PBXBuildFile(file: fileReference, settings: getEmbedSettings(dependency: dependency, codeSign: dependency.codeSign ?? true))
                    )
                    if dependency.copyPhase != nil {
                        customCopyDependenciesReferences.append(embedFile)
                    } else {
                        copyFrameworksReferences.append(embedFile)
                    }
                } else {
                    carthageFrameworksToEmbed.append(dependency.reference)
                }
            }
        }
        
        carthageFrameworksToEmbed = carthageFrameworksToEmbed.uniqued()

        var buildPhases: [PBXBuildPhase] = []

        func getBuildFilesForSourceFiles(_ sourceFiles: [SourceFile]) -> [PBXBuildFile] {
            sourceFiles
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

        func getBuildFilesForCopyFilesPhases() -> [BuildPhaseSpec.CopyFilesSettings: [PBXBuildFile]] {
            var sourceFilesByCopyFiles: [BuildPhaseSpec.CopyFilesSettings: [SourceFile]] = [:]
            for sourceFile in sourceFiles {
                guard case let .copyFiles(copyFilesSettings)? = sourceFile.buildPhase else { continue }
                sourceFilesByCopyFiles[copyFilesSettings, default: []].append(sourceFile)
            }
            return sourceFilesByCopyFiles.mapValues { getBuildFilesForSourceFiles($0) }
        }

        func getPBXCopyFilesBuildPhase(dstSubfolderSpec: PBXCopyFilesBuildPhase.SubFolder, dstPath: String = "", name: String, files: [PBXBuildFile]) -> PBXCopyFilesBuildPhase {
            return PBXCopyFilesBuildPhase(
                dstPath: dstPath,
                dstSubfolderSpec: dstSubfolderSpec,
                name: name,
                buildActionMask: target.onlyCopyFilesOnInstall ? PBXProjGenerator.copyFilesActionMask : PBXBuildPhase.defaultBuildActionMask,
                files: files,
                runOnlyForDeploymentPostprocessing: target.onlyCopyFilesOnInstall ? true : false
            )
        }
        
        func splitCopyDepsByDestination(_ references: [PBXBuildFile]) -> [BuildPhaseSpec.CopyFilesSettings : [PBXBuildFile]] {
        
            var retval = [BuildPhaseSpec.CopyFilesSettings : [PBXBuildFile]]()
            for reference in references {
                
                guard let key = reference.settings?["COPY_PHASE"] as? BuildPhaseSpec.CopyFilesSettings else { continue }
                var filesWithSameDestination = retval[key] ?? [PBXBuildFile]()
                filesWithSameDestination.append(reference)
                retval[key] = filesWithSameDestination
            }
            return retval
        }
        
        copyFilesBuildPhasesFiles.merge(getBuildFilesForCopyFilesPhases()) { $0 + $1 }

        buildPhases += try target.preBuildScripts.map { try generateBuildScript(targetName: target.name, buildScript: $0) }

        buildPhases += copyFilesBuildPhasesFiles
            .filter { $0.key.phaseOrder == .preCompile }
            .map { generateCopyFiles(targetName: target.name, copyFiles: $0, buildPhaseFiles: $1) }

        let headersBuildPhaseFiles = getBuildFilesForPhase(.headers)
        if !headersBuildPhaseFiles.isEmpty {
            if target.type.isFramework || target.type == .dynamicLibrary {
                let headersBuildPhase = addObject(PBXHeadersBuildPhase(files: headersBuildPhaseFiles))
                buildPhases.append(headersBuildPhase)
            } else {
                headersBuildPhaseFiles.forEach { pbxProj.delete(object: $0) }
            }
        }

        let sourcesBuildPhaseFiles = getBuildFilesForPhase(.sources)
        let shouldSkipSourcesBuildPhase = sourcesBuildPhaseFiles.isEmpty && target.type.canSkipCompileSourcesBuildPhase
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
        let swiftInstallObjCHeader = project.getBoolBuildSetting("SWIFT_INSTALL_OBJC_HEADER", target: target, config: project.configs[0]) ?? true // Xcode default

        if target.type == .staticLibrary
            && swiftObjCInterfaceHeader != ""
            && swiftInstallObjCHeader
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
                .map { "$(SRCROOT)/\(carthageResolver.buildPath(for: target.platform, linkType: .dynamic))/\($0)\($0.contains(".") ? "" : ".framework")" }
            let outputPaths = carthageFrameworksToEmbed
                .map { "$(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/\($0)\($0.contains(".") ? "" : ".framework")" }
            let carthageExecutable = carthageResolver.executable
            let carthageScript = addObject(
                PBXShellScriptBuildPhase(
                    name: "Carthage",
                    inputPaths: inputPaths,
                    outputPaths: outputPaths,
                    shellPath: "/bin/sh -l",
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

        if !copyBundlesReferences.isEmpty {
            let copyBundlesPhase = addObject(PBXCopyFilesBuildPhase(
                dstSubfolderSpec: .resources,
                name: "Copy Bundle Resources",
                files: copyBundlesReferences
            ))
            buildPhases.append(copyBundlesPhase)
        }

        if !extensions.isEmpty {

            let copyFilesPhase = addObject(
                getPBXCopyFilesBuildPhase(dstSubfolderSpec: .plugins, name: "Embed App Extensions", files: extensions)
            )

            buildPhases.append(copyFilesPhase)
        }

        if !extensionKitExtensions.isEmpty {

            let copyFilesPhase = addObject(
                getPBXCopyFilesBuildPhase(dstSubfolderSpec: .productsDirectory, dstPath: "$(EXTENSIONS_FOLDER_PATH)", name: "Embed ExtensionKit Extensions", files: extensionKitExtensions)
            )
            buildPhases.append(copyFilesPhase)
        }

        if !systemExtensions.isEmpty {

            let copyFilesPhase = addObject(
                // With parameters below the Xcode will show "Destination: System Extensions".
                getPBXCopyFilesBuildPhase(dstSubfolderSpec: .productsDirectory, dstPath: "$(SYSTEM_EXTENSIONS_FOLDER_PATH)", name: "Embed System Extensions", files: systemExtensions)
            )

            buildPhases.append(copyFilesPhase)
        }

        if !appClips.isEmpty {

            let copyFilesPhase = addObject(
                PBXCopyFilesBuildPhase(
                    dstPath: "$(CONTENTS_FOLDER_PATH)/AppClips",
                    dstSubfolderSpec: .productsDirectory,
                    name: "Embed App Clips",
                    files: appClips
                )
            )

            buildPhases.append(copyFilesPhase)
        }

        copyFrameworksReferences += getBuildFilesForPhase(.frameworks)
        if !copyFrameworksReferences.isEmpty {

            let copyFilesPhase = addObject(
                getPBXCopyFilesBuildPhase(dstSubfolderSpec: .frameworks, name: "Embed Frameworks", files: copyFrameworksReferences)
            )

            buildPhases.append(copyFilesPhase)
        }

        if !customCopyDependenciesReferences.isEmpty {
            
            let splitted = splitCopyDepsByDestination(customCopyDependenciesReferences)
            for (phase, references) in splitted {
                
                guard let destination = phase.destination.destination else { continue }
                
                let copyFilesPhase = addObject(
                    getPBXCopyFilesBuildPhase(dstSubfolderSpec: destination, dstPath:phase.subpath, name: "Embed Dependencies", files: references)
                )

                buildPhases.append(copyFilesPhase)
            }
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
                    script: buildRule.action.script,
                    runOncePerArchitecture: buildRule.runOncePerArchitecture
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

            // Set INFOPLIST_FILE based on the resolved value
            if let infoPlistFile = infoPlistFiles[config] {
                buildSettings["INFOPLIST_FILE"] = infoPlistFile
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
            if target.type == .uiTestBundle,
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
                var carthagePlatformBuildPaths: Set<String> = []
                if carthageDependencies.contains(where: { $0.dependency.carthageLinkType == .static }) {
                    let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, linkType: .static)
                    carthagePlatformBuildPaths.insert(carthagePlatformBuildPath)
                }
                if carthageDependencies.contains(where: { $0.dependency.carthageLinkType == .dynamic }) {
                    let carthagePlatformBuildPath = "$(PROJECT_DIR)/" + carthageResolver.buildPath(for: target.platform, linkType: .dynamic)
                    carthagePlatformBuildPaths.insert(carthagePlatformBuildPath)
                }
                configFrameworkBuildPaths = carthagePlatformBuildPaths.sorted() + frameworkBuildPaths.sorted()
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

        let defaultConfigurationName = project.options.defaultConfig ?? project.configs.first?.name ?? ""
        let buildConfigList = addObject(XCConfigurationList(
            buildConfigurations: configs,
            defaultConfigurationName: defaultConfigurationName
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
    
    private func makePlatformFilter(for filter: Dependency.PlatformFilter) -> String? {
        switch filter {
        case .all:
            return nil
        case .macOS:
            return "maccatalyst"
        case .iOS:
            return "ios"
        }
    }

    func getInfoPlists(for target: Target) -> [Config: String] {
        var searchForDefaultInfoPlist: Bool = true
        var defaultInfoPlist: String?

        let values: [(Config, String)] = project.configs.compactMap { config in
            // First, if the plist path was defined by `INFOPLIST_FILE`, use that
            let buildSettings = project.getTargetBuildSettings(target: target, config: config)
            if let value = buildSettings["INFOPLIST_FILE"] as? String {
                return (config, value)
            }

            // Otherwise check if the path was defined as part of the `info` spec
            if let value = target.info?.path {
                return (config, value)
            }

            // If we haven't yet looked for the default info plist, try doing so
            if searchForDefaultInfoPlist {
                searchForDefaultInfoPlist = false

                if let plistPath = getInfoPlist(target.sources) {
                    let basePath = projectDirectory ?? project.basePath.absolute()
                    let relative = (try? plistPath.relativePath(from: basePath)) ?? plistPath
                    defaultInfoPlist = relative.string
                }
            }

            // Return the default plist if there was one
            if let value = defaultInfoPlist {
                return (config, value)
            }
            return nil
        }

        return Dictionary(uniqueKeysWithValues: values)
    }

    func getInfoPlist(_ sources: [TargetSource]) -> Path? {
        sources
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
                if dependencies[dependency.uniqueID] != nil {
                    continue
                }

                // don't want a dependency if it's going to be embedded or statically linked in a non-top level target
                // in .target check we filter out targets that will embed all of their dependencies
                // For some more context about the `dependency.embed != true` lines, refer to https://github.com/yonaskolb/XcodeGen/pull/820
                switch dependency.type {
                case .sdk:
                    dependencies[dependency.uniqueID] = dependency
                case .framework, .carthage, .package:
                    if isTopLevel || dependency.embed != true {
                        dependencies[dependency.uniqueID] = dependency
                    }
                case .target:
                    let dependencyTargetReference = try! TargetReference(dependency.reference)

                    switch dependencyTargetReference.location {
                    case .local:
                        if isTopLevel || dependency.embed != true {
                            if let dependencyTarget = project.getTarget(dependency.reference) {
                                dependencies[dependency.uniqueID] = dependency
                                if !dependencyTarget.shouldEmbedDependencies {
                                    // traverse target's dependencies if it doesn't embed them itself
                                    queue.append(dependencyTarget)
                                }
                            } else if project.getAggregateTarget(dependency.reference) != nil {
                                // Aggregate targets should be included
                                dependencies[dependency.uniqueID] = dependency
                            }
                        }
                    case .project:
                        if isTopLevel || dependency.embed != true {
                            dependencies[dependency.uniqueID] = dependency
                        }
                    }
                case .bundle:
                    if isTopLevel {
                        dependencies[dependency.uniqueID] = dependency
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
        type.isApp || type.isTest
    }

    var shouldEmbedCarthageDependencies: Bool {
        (type.isApp && platform != .watchOS)
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

private extension Dependency {
    var carthageLinkType: Dependency.CarthageLinkType? {
        switch type {
        case .carthage(_, let linkType):
            return linkType
        default:
            return nil
        }
    }
}
