import Foundation
import ProjectSpec
import XcodeProj
import PathKit

private func suitableConfig(for type: ConfigType, in project: Project) -> Config {
    if let defaultConfig = Config.defaultConfigs.first(where: { $0.type == type }),
        project.configs.contains(defaultConfig) {
        return defaultConfig
    }
    return project.configs.first { $0.type == type }!
}

public class SchemeGenerator {

    let project: Project
    let pbxProj: PBXProj

    var defaultDebugConfig: Config {
        suitableConfig(for: .debug, in: project)
    }

    var defaultReleaseConfig: Config {
        suitableConfig(for: .release, in: project)
    }

    public init(project: Project, pbxProj: PBXProj) {
        self.project = project
        self.pbxProj = pbxProj
    }

    private var projects: [ProjectReference: PBXProj] = [:]

    func getPBXProj(from reference: ProjectReference) throws -> PBXProj {
        if let cachedProject = projects[reference] {
            return cachedProject
        }
        let pbxproj = try XcodeProj(path: project.basePath + Path(reference.path)).pbxproj
        projects[reference] = pbxproj
        return pbxproj
    }

    public func generateSchemes() throws -> (
        shared: [XCScheme],
        user: [XCScheme],
        management: XCSchemeManagement?
    ) {
        var schemes: [(Scheme, ProjectTarget?)] = []

        for scheme in project.schemes {
            schemes.append((scheme, nil))
        }

        for target in project.projectTargets {
            if let targetScheme = target.scheme {
                if targetScheme.configVariants.isEmpty {
                    let schemeName = target.name

                    let debugConfig = suitableConfig(for: .debug, in: project)
                    let releaseConfig = suitableConfig(for: .release, in: project)

                    let scheme = Scheme(
                        name: schemeName,
                        target: target,
                        targetScheme: targetScheme,
                        project: project,
                        debugConfig: debugConfig.name,
                        releaseConfig: releaseConfig.name
                    )
                    schemes.append((scheme, target))
                } else {
                    for configVariant in targetScheme.configVariants {

                        let schemeName = "\(target.name) \(configVariant)"

                        let debugConfig = project.configs
                            .first(including: configVariant, for: .debug)!

                        let releaseConfig = project.configs
                            .first(including: configVariant, for: .release)!

                        let scheme = Scheme(
                            name: schemeName,
                            target: target,
                            targetScheme: targetScheme,
                            project: project,
                            debugConfig: debugConfig.name,
                            releaseConfig: releaseConfig.name
                        )
                        schemes.append((scheme, target))
                    }
                }
            }
        }

        var sharedSchemes: [XCScheme] = []
        var userSchemes: [XCScheme] = []
        var schemeManagements: [XCSchemeManagement.UserStateScheme] = []

        for (scheme, projectTarget) in schemes {
            let xcscheme = try generateScheme(scheme, for: projectTarget)

            if scheme.management?.shared == false {
                userSchemes.append(xcscheme)
            } else {
                sharedSchemes.append(xcscheme)
            }

            if let management = scheme.management {
                schemeManagements.append(
                    XCSchemeManagement.UserStateScheme(
                        name: scheme.name + ".xcscheme",
                        shared: management.shared,
                        orderHint: management.orderHint,
                        isShown: management.isShown
                    )
                )
            }
        }

        return (
            shared: sharedSchemes,
            user: userSchemes,
            management: schemeManagements.isEmpty
                ? nil
                : XCSchemeManagement(schemeUserState: schemeManagements, suppressBuildableAutocreation: nil)
        )
    }

    public func generateScheme(_ scheme: Scheme, for target: ProjectTarget? = nil) throws -> XCScheme {

        func getBuildableReference(_ target: TargetReference) throws -> XCScheme.BuildableReference {
            let pbxProj: PBXProj
            let projectFilePath: String
            switch target.location {
            case .project(let project):
                guard let projectReference = self.project.getProjectReference(project) else {
                    throw SchemeGenerationError.missingProject(project)
                }
                pbxProj = try getPBXProj(from: projectReference)
                projectFilePath = projectReference.path
            case .local:
                pbxProj = self.pbxProj
                projectFilePath = "\(self.project.name).xcodeproj"
            }

            guard let pbxTarget = pbxProj.targets(named: target.name).first else {
                throw SchemeGenerationError.missingTarget(target, projectPath: projectFilePath)
            }
            let buildableName: String

            switch target.location {
            case .project:
                buildableName = pbxTarget.productNameWithExtension() ?? pbxTarget.name
            case .local:
                guard let _buildableName =
                    project.getTarget(target.name)?.filename ??
                    project.getAggregateTarget(target.name)?.name else {
                    fatalError("Unable to determinate \"buildableName\" for build target: \(target)")
                }
                buildableName = _buildableName
            }

            return XCScheme.BuildableReference(
                referencedContainer: "container:\(projectFilePath)",
                blueprint: pbxTarget,
                buildableName: buildableName,
                blueprintName: target.name
            )
        }
        
        func getBuildableTestableReference(_ target: TestableTargetReference) throws -> XCScheme.BuildableReference {
            switch target.location {
            case .package(let packageName):
                guard let package = self.project.getPackage(packageName),
                      case let .local(path, _) = package else {
                    throw SchemeGenerationError.missingPackage(packageName)
                }
                return XCScheme.BuildableReference(
                    referencedContainer: "container:\(path)",
                    blueprintIdentifier: target.name,
                    buildableName: target.name,
                    blueprintName: target.name
                )
            default:
                return try getBuildableReference(target.targetReference)
            }
        }

        func getBuildEntry(_ buildTarget: Scheme.BuildTarget) throws -> XCScheme.BuildAction.Entry {
            let buildableReference = try getBuildableTestableReference(buildTarget.target)
            return XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: buildTarget.buildTypes)
        }

        let testTargets = scheme.test?.targets ?? []
        let testBuildTargets = testTargets.map {
            Scheme.BuildTarget(target: $0.targetReference, buildTypes: BuildType.testOnly)
        }

        let testBuildTargetEntries = try testBuildTargets.map(getBuildEntry)

        let buildActionEntries: [XCScheme.BuildAction.Entry] = try scheme.build.targets.map(getBuildEntry)

        func getExecutionAction(_ action: Scheme.ExecutionAction) -> XCScheme.ExecutionAction {
            // ExecutionActions can require the use of build settings. Xcode allows the settings to come from a build or test target.
            let environmentBuildable = action.settingsTarget.flatMap { settingsTarget in
                (buildActionEntries + testBuildTargetEntries)
                    .first { settingsTarget == $0.buildableReference.blueprintName }?
                    .buildableReference
            }
            return XCScheme.ExecutionAction(
                scriptText: action.script,
                title: action.name,
                shellToInvoke: action.shell,
                environmentBuildable: environmentBuildable
            )
        }

        let schemeTarget: ProjectTarget?

        if let targetName = scheme.run?.executable {
            schemeTarget = project.getTarget(targetName)
        } else {
            guard let firstTarget = scheme.build.targets.first else {
                throw SchemeGenerationError.missingBuildTargets(scheme.name)
            }
            let name = scheme.build.targets.first { $0.buildTypes.contains(.running) }?.target.name ?? firstTarget.target.name
            schemeTarget = target ?? project.getTarget(name)
        }

        let shouldExecuteOnLaunch = schemeTarget?.shouldExecuteOnLaunch == true

        let buildableReference = buildActionEntries.first(where: { $0.buildableReference.blueprintName == schemeTarget?.name })?.buildableReference ?? buildActionEntries.first!.buildableReference
        let runnables = makeProductRunnables(for: schemeTarget, buildableReference: buildableReference)

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: buildActionEntries,
            preActions: scheme.build.preActions.map(getExecutionAction),
            postActions: scheme.build.postActions.map(getExecutionAction),
            parallelizeBuild: scheme.build.parallelizeBuild,
            buildImplicitDependencies: scheme.build.buildImplicitDependencies,
            runPostActionsOnFailure: scheme.build.runPostActionsOnFailure
        )

        let testables: [XCScheme.TestableReference] = zip(testTargets, testBuildTargetEntries).map { testTarget, testBuildEntries in
            
            var locationScenarioReference: XCScheme.LocationScenarioReference?
            if var location = testTarget.location {
                
                if location.contains(".gpx") {
                    var path = Path(components: [project.options.schemePathPrefix, location])
                    path = path.simplifyingParentDirectoryReferences()
                    location = path.string
                }
                
                let referenceType = location.contains(".gpx") ? "0" : "1"
                locationScenarioReference = XCScheme.LocationScenarioReference(identifier: location, referenceType: referenceType)
                
            }
            
            return XCScheme.TestableReference(
                skipped: testTarget.skipped,
                parallelizable: testTarget.parallelizable,
                randomExecutionOrdering: testTarget.randomExecutionOrder,
                buildableReference: testBuildEntries.buildableReference,
                locationScenarioReference: locationScenarioReference,
                skippedTests: testTarget.skippedTests.map(XCScheme.TestItem.init),
                selectedTests: testTarget.selectedTests.map(XCScheme.TestItem.init),
                useTestSelectionWhitelist: !testTarget.selectedTests.isEmpty ? true : nil
            )
        }

        let coverageBuildableTargets = try scheme.test?.coverageTargets.map {
            try getBuildableTestableReference($0)
        } ?? []

        let testCommandLineArgs = scheme.test.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let launchCommandLineArgs = scheme.run.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let profileCommandLineArgs = scheme.profile.map { XCScheme.CommandLineArguments($0.commandLineArguments) }

        let testVariables = scheme.test.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }
        let launchVariables = scheme.run.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }
        let profileVariables = scheme.profile.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }

        let defaultTestPlanIndex = scheme.test?.testPlans.firstIndex { $0.defaultPlan } ?? 0
        let testPlans = scheme.test?.testPlans.enumerated().map { index, testPlan in
             XCScheme.TestPlanReference(reference: "container:\(testPlan.path)", default: defaultTestPlanIndex == index)
        } ?? []
        let testBuildableEntries = buildActionEntries.filter({ $0.buildFor.contains(.testing) }) + testBuildTargetEntries
        let testMacroExpansionBuildableRef = testBuildableEntries.map(\.buildableReference).contains(buildableReference) ? buildableReference : testBuildableEntries.first?.buildableReference

        let testMacroExpansion: XCScheme.BuildableReference = buildActionEntries.first(
            where: { value in
                if let macroExpansion = scheme.test?.macroExpansion {
                    return value.buildableReference.blueprintName == macroExpansion
                }
                return false
            }
        )?.buildableReference ?? testMacroExpansionBuildableRef ?? buildableReference

        let testAction = XCScheme.TestAction(
            buildConfiguration: scheme.test?.config ?? defaultDebugConfig.name,
            macroExpansion: testMacroExpansion,
            testables: testables,
            testPlans: testPlans.isEmpty ? nil : testPlans,
            preActions: scheme.test?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.test?.postActions.map(getExecutionAction) ?? [],
            selectedDebuggerIdentifier: (scheme.test?.debugEnabled ?? Scheme.Test.debugEnabledDefault) ? XCScheme.defaultDebugger : "",
            selectedLauncherIdentifier: (scheme.test?.debugEnabled ?? Scheme.Test.debugEnabledDefault) ? XCScheme.defaultLauncher : "Xcode.IDEFoundation.Launcher.PosixSpawn",
            shouldUseLaunchSchemeArgsEnv: scheme.test?.shouldUseLaunchSchemeArgsEnv ?? true,
            codeCoverageEnabled: scheme.test?.gatherCoverageData ?? Scheme.Test.gatherCoverageDataDefault,
            codeCoverageTargets: coverageBuildableTargets,
            onlyGenerateCoverageForSpecifiedTargets: !coverageBuildableTargets.isEmpty,
            disableMainThreadChecker: scheme.test?.disableMainThreadChecker ?? Scheme.Test.disableMainThreadCheckerDefault,
            commandlineArguments: testCommandLineArgs,
            environmentVariables: testVariables,
            language: scheme.test?.language,
            region: scheme.test?.region,
            systemAttachmentLifetime: scheme.test?.systemAttachmentLifetime,
            customLLDBInitFile: scheme.test?.customLLDBInit
        )

        let allowLocationSimulation = scheme.run?.simulateLocation?.allow ?? true
        var locationScenarioReference: XCScheme.LocationScenarioReference?
        if let simulateLocation = scheme.run?.simulateLocation, var identifier = simulateLocation.defaultLocation, let referenceType = simulateLocation.referenceType {
            if referenceType == .gpx {
                var path = Path(components: [project.options.schemePathPrefix, identifier])
                path = path.simplifyingParentDirectoryReferences()
                identifier = path.string
            }
            locationScenarioReference = XCScheme.LocationScenarioReference(identifier: identifier, referenceType: referenceType.rawValue)
        }

        var storeKitConfigurationFileReference: XCScheme.StoreKitConfigurationFileReference?
        if let storeKitConfiguration = scheme.run?.storeKitConfiguration {
            let storeKitConfigurationPath = Path(components: [project.options.schemePathPrefix, storeKitConfiguration]).simplifyingParentDirectoryReferences()
            storeKitConfigurationFileReference = XCScheme.StoreKitConfigurationFileReference(identifier: storeKitConfigurationPath.string)
        }

        let macroExpansion: XCScheme.BuildableReference?
        if let macroExpansionName = scheme.run?.macroExpansion,
           let resolvedMacroExpansion = buildActionEntries.first(where: { $0.buildableReference.blueprintName == macroExpansionName })?.buildableReference {
            macroExpansion = resolvedMacroExpansion
        } else {
            macroExpansion = shouldExecuteOnLaunch ? nil : buildableReference
        }

        let launchAction = XCScheme.LaunchAction(
            runnable: shouldExecuteOnLaunch ? runnables.launch : nil,
            buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
            preActions: scheme.run?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.run?.postActions.map(getExecutionAction) ?? [],
            macroExpansion: macroExpansion,
            selectedDebuggerIdentifier: selectedDebuggerIdentifier(for: schemeTarget, run: scheme.run),
            selectedLauncherIdentifier: selectedLauncherIdentifier(for: schemeTarget, run: scheme.run),
            askForAppToLaunch: scheme.run?.askForAppToLaunch,
            allowLocationSimulation: allowLocationSimulation,
            locationScenarioReference: locationScenarioReference,
            enableGPUFrameCaptureMode: scheme.run?.enableGPUFrameCaptureMode ?? XCScheme.LaunchAction.defaultGPUFrameCaptureMode,
            enableGPUValidationMode: scheme.run?.enableGPUValidationMode ?? XCScheme.LaunchAction.defaultGPUValidationMode,
            disableMainThreadChecker: scheme.run?.disableMainThreadChecker ?? Scheme.Run.disableMainThreadCheckerDefault,
            disablePerformanceAntipatternChecker: scheme.run?.disableThreadPerformanceChecker ?? Scheme.Run.disableThreadPerformanceCheckerDefault,
            stopOnEveryMainThreadCheckerIssue: scheme.run?.stopOnEveryMainThreadCheckerIssue ?? Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault,
            commandlineArguments: launchCommandLineArgs,
            environmentVariables: launchVariables,
            language: scheme.run?.language,
            region: scheme.run?.region,
            launchAutomaticallySubstyle: scheme.run?.launchAutomaticallySubstyle ?? launchAutomaticallySubstyle(for: schemeTarget),
            storeKitConfigurationFileReference: storeKitConfigurationFileReference,
            customLLDBInitFile: scheme.run?.customLLDBInit
        )

        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: shouldExecuteOnLaunch ? runnables.profile : nil,
            buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name,
            preActions: scheme.profile?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.profile?.postActions.map(getExecutionAction) ?? [],
            macroExpansion: shouldExecuteOnLaunch ? nil : buildableReference,
            shouldUseLaunchSchemeArgsEnv: scheme.profile?.shouldUseLaunchSchemeArgsEnv ?? true,
            askForAppToLaunch: scheme.profile?.askForAppToLaunch,
            commandlineArguments: profileCommandLineArgs,
            environmentVariables: profileVariables
        )

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: scheme.analyze?.config ?? defaultDebugConfig.name)

        let archiveAction = XCScheme.ArchiveAction(
            buildConfiguration: scheme.archive?.config ?? defaultReleaseConfig.name,
            revealArchiveInOrganizer: scheme.archive?.revealArchiveInOrganizer ?? true,
            customArchiveName: scheme.archive?.customArchiveName,
            preActions: scheme.archive?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.archive?.postActions.map(getExecutionAction) ?? []
        )

        let lastUpgradeVersion = project.attributes["LastUpgradeCheck"] as? String ?? project.xcodeVersion

        return XCScheme(
            name: scheme.name,
            lastUpgradeVersion: lastUpgradeVersion,
            version: project.schemeVersion,
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction,
            wasCreatedForAppExtension: schemeTarget
                .flatMap { $0.type.isExtension ? true : nil }
        )
    }
    
    private func launchAutomaticallySubstyle(for target: ProjectTarget?) -> String? {
        if target?.type.isExtension == true {
            return "2"
        } else {
            return nil
        }
    }

    private func makeProductRunnables(for target: ProjectTarget?, buildableReference: XCScheme.BuildableReference) -> (launch: XCScheme.Runnable, profile: XCScheme.BuildableProductRunnable) {
        let buildable = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)
        if target?.type.isWatchApp == true {
            let remote = XCScheme.RemoteRunnable(
                buildableReference: buildableReference,
                bundleIdentifier: "com.apple.Carousel",
                runnableDebuggingMode: "2"
            )
            return (remote, buildable)
        } else {
            return (buildable, buildable)
        }
    }

    private func selectedDebuggerIdentifier(for target: ProjectTarget?, run: Scheme.Run?) -> String {
        if target?.type.canUseDebugLauncher != false && run?.debugEnabled ?? Scheme.Run.debugEnabledDefault {
            return XCScheme.defaultDebugger
        } else {
            return ""
        }
    }

    private func selectedLauncherIdentifier(for target: ProjectTarget?, run: Scheme.Run?) -> String {
        if target?.type.canUseDebugLauncher != false && run?.debugEnabled ?? Scheme.Run.debugEnabledDefault {
            return XCScheme.defaultLauncher
        } else {
            return "Xcode.IDEFoundation.Launcher.PosixSpawn"
        }
    }
}

enum SchemeGenerationError: Error, CustomStringConvertible {

    case missingTarget(TargetReference, projectPath: String)
    case missingPackage(String)
    case missingProject(String)
    case missingBuildTargets(String)

    var description: String {
        switch self {
        case .missingTarget(let target, let projectPath):
            return "Unable to find target named \"\(target)\" in \"\(projectPath)\""
        case .missingProject(let project):
            return "Unable to find project reference named \"\(project)\" in project.yml"
        case .missingBuildTargets(let name):
            return "Unable to find at least one build target in scheme \"\(name)\""
        case .missingPackage(let package):
            return "Unable to find swift package named \"\(package)\" in project.yml"
        }
    }
}

extension Scheme {
    public init(name: String, target: ProjectTarget, targetScheme: TargetScheme, project: Project, debugConfig: String, releaseConfig: String) {
        self.init(
            name: name,
            build: .init(
                targets: Scheme.buildTargets(for: target, project: project),
                buildImplicitDependencies: targetScheme.buildImplicitDependencies,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions
            ),
            run: .init(
                config: debugConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                stopOnEveryMainThreadCheckerIssue: targetScheme.stopOnEveryMainThreadCheckerIssue,
                disableThreadPerformanceChecker: targetScheme.disableThreadPerformanceChecker,
                language: targetScheme.language,
                region: targetScheme.region,
                storeKitConfiguration: targetScheme.storeKitConfiguration
            ),
            test: .init(
                config: debugConfig,
                gatherCoverageData: targetScheme.gatherCoverageData,
                coverageTargets: targetScheme.coverageTargets,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                commandLineArguments: targetScheme.commandLineArguments,
                targets: targetScheme.testTargets,
                environmentVariables: targetScheme.environmentVariables,
                testPlans: targetScheme.testPlans,
                language: targetScheme.language,
                region: targetScheme.region
            ),
            profile: .init(
                config: releaseConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables
            ),
            analyze: .init(
                config: debugConfig
            ),
            archive: .init(
                config: releaseConfig
            ),
            management: targetScheme.management
        )
    }

    private static func buildTargets(for target: ProjectTarget, project: Project) -> [BuildTarget] {
        let buildTarget = Scheme.BuildTarget(target: TestableTargetReference.local(target.name))
        switch target.type {
        case .watchApp, .watch2App:
            let hostTarget = project.targets
                .first { projectTarget in
                    projectTarget.dependencies.contains { $0.reference == target.name }
                }
                .map { BuildTarget(target: TestableTargetReference.local($0.name)) }
            return hostTarget.map { [buildTarget, $0] } ?? [buildTarget]
        default:
            return [buildTarget]
        }
    }
}

extension PBXProductType {
    var canUseDebugLauncher: Bool {
        // Extensions don't use the lldb launcher
        return !isExtension
    }

    var isWatchApp: Bool {
        switch self {
        case .watchApp, .watch2App:
            return true
        default:
            return false
        }
    }
}

extension Scheme.Test {
    var systemAttachmentLifetime: XCScheme.TestAction.AttachmentLifetime? {
        switch (captureScreenshotsAutomatically, deleteScreenshotsWhenEachTestSucceeds) {
        case (false, _):
            return .keepNever
        case (true, false):
            return .keepAlways
        case (true, true):
            return nil
        }
    }
}
