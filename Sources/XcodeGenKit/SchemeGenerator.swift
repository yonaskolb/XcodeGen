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

    public func generateSchemes() throws -> [XCScheme] {
        var xcschemes: [XCScheme] = []

        for scheme in project.schemes {
            let xcscheme = try generateScheme(scheme)
            xcschemes.append(xcscheme)
        }

        for target in project.targets {
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
                    let xcscheme = try generateScheme(scheme, for: target)
                    xcschemes.append(xcscheme)
                } else {
                    for configVariant in targetScheme.configVariants {

                        let schemeName = "\(target.name) \(configVariant)"

                        let debugConfig = project.configs
                            .first { $0.type == .debug && $0.name.contains(configVariant) }!
                        let releaseConfig = project.configs
                            .first { $0.type == .release && $0.name.contains(configVariant) }!

                        let scheme = Scheme(
                            name: schemeName,
                            target: target,
                            targetScheme: targetScheme,
                            project: project,
                            debugConfig: debugConfig.name,
                            releaseConfig: releaseConfig.name
                        )
                        let xcscheme = try generateScheme(scheme, for: target)
                        xcschemes.append(xcscheme)
                    }
                }
            }
        }

        return xcschemes
    }

    public func generateScheme(_ scheme: Scheme, for target: Target? = nil) throws -> XCScheme {

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

        func getBuildEntry(_ buildTarget: Scheme.BuildTarget) throws -> XCScheme.BuildAction.Entry {
            let buildableReference = try getBuildableReference(buildTarget.target)
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
            return XCScheme.ExecutionAction(scriptText: action.script, title: action.name, environmentBuildable: environmentBuildable)
        }

        let schemeTarget: Target?

        if let targetName = scheme.run?.executable {
            schemeTarget = project.getTarget(targetName)
        } else {
            let name = scheme.build.targets.first { $0.buildTypes.contains(.running) }?.target.name ?? scheme.build.targets.first!.target.name
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
            buildImplicitDependencies: scheme.build.buildImplicitDependencies
        )

        let testables = zip(testTargets, testBuildTargetEntries).map { testTarget, testBuilEntries in
            XCScheme.TestableReference(
                skipped: testTarget.skipped,
                parallelizable: testTarget.parallelizable,
                randomExecutionOrdering: testTarget.randomExecutionOrder,
                buildableReference: testBuilEntries.buildableReference,
                skippedTests: testTarget.skippedTests.map(XCScheme.TestItem.init)
            )
        }

        let coverageBuildableTargets = try scheme.test?.coverageTargets.map {
            try getBuildableReference($0)
        } ?? []

        let testCommandLineArgs = scheme.test.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let launchCommandLineArgs = scheme.run.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let profileCommandLineArgs = scheme.profile.map { XCScheme.CommandLineArguments($0.commandLineArguments) }

        let testVariables = scheme.test.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }
        let launchVariables = scheme.run.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }
        let profileVariables = scheme.profile.flatMap { $0.environmentVariables.isEmpty ? nil : $0.environmentVariables }

        let testAction = XCScheme.TestAction(
            buildConfiguration: scheme.test?.config ?? defaultDebugConfig.name,
            macroExpansion: buildableReference,
            testables: testables,
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
            customLLDBInitFile: scheme.test?.customLLDBInit
        )

        let allowLocationSimulation = scheme.run?.simulateLocation?.allow ?? true
        var locationScenarioReference: XCScheme.LocationScenarioReference?
        if let simulateLocation = scheme.run?.simulateLocation, var identifier = simulateLocation.defaultLocation, let referenceType = simulateLocation.referenceType {
            if referenceType == .gpx {
                var path = Path("../\(identifier)")
                path = path.simplifyingParentDirectoryReferences()
                identifier = path.string
            }
            locationScenarioReference = XCScheme.LocationScenarioReference(identifier: identifier, referenceType: referenceType.rawValue)
        }

        let launchAction = XCScheme.LaunchAction(
            runnable: shouldExecuteOnLaunch ? runnables.launch : nil,
            buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
            preActions: scheme.run?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.run?.postActions.map(getExecutionAction) ?? [],
            macroExpansion: shouldExecuteOnLaunch ? nil : buildableReference,
            selectedDebuggerIdentifier: selectedDebuggerIdentifier(for: schemeTarget, run: scheme.run),
            selectedLauncherIdentifier: selectedLauncherIdentifier(for: schemeTarget, run: scheme.run),
            askForAppToLaunch: scheme.run?.askForAppToLaunch,
            allowLocationSimulation: allowLocationSimulation,
            locationScenarioReference: locationScenarioReference,
            disableMainThreadChecker: scheme.run?.disableMainThreadChecker ?? Scheme.Run.disableMainThreadCheckerDefault,
            stopOnEveryMainThreadCheckerIssue: scheme.run?.stopOnEveryMainThreadCheckerIssue ?? Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault,
            commandlineArguments: launchCommandLineArgs,
            environmentVariables: launchVariables,
            language: scheme.run?.language,
            region: scheme.run?.region,
            launchAutomaticallySubstyle: scheme.run?.launchAutomaticallySubstyle ?? launchAutomaticallySubstyle(for: schemeTarget),
            customLLDBInitFile: scheme.run?.customLLDBInit
        )

        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: runnables.profile,
            buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name,
            preActions: scheme.profile?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.profile?.postActions.map(getExecutionAction) ?? [],
            shouldUseLaunchSchemeArgsEnv: scheme.profile?.shouldUseLaunchSchemeArgsEnv ?? true,
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

        return XCScheme(
            name: scheme.name,
            lastUpgradeVersion: project.xcodeVersion,
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

    private func launchAutomaticallySubstyle(for target: Target?) -> String? {
        if target?.type.isExtension == true {
            return "2"
        } else {
            return nil
        }
    }

    private func makeProductRunnables(for target: Target?, buildableReference: XCScheme.BuildableReference) -> (launch: XCScheme.Runnable, profile: XCScheme.BuildableProductRunnable) {
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

    private func selectedDebuggerIdentifier(for target: Target?, run: Scheme.Run?) -> String {
        if target?.type.canUseDebugLauncher != false && run?.debugEnabled ?? Scheme.Run.debugEnabledDefault {
            return XCScheme.defaultDebugger
        } else {
            return ""
        }
    }

    private func selectedLauncherIdentifier(for target: Target?, run: Scheme.Run?) -> String {
        if target?.type.canUseDebugLauncher != false && run?.debugEnabled ?? Scheme.Run.debugEnabledDefault {
            return XCScheme.defaultLauncher
        } else {
            return "Xcode.IDEFoundation.Launcher.PosixSpawn"
        }
    }
}

enum SchemeGenerationError: Error, CustomStringConvertible {

    case missingTarget(TargetReference, projectPath: String)
    case missingProject(String)

    var description: String {
        switch self {
        case .missingTarget(let target, let projectPath):
            return "Unable to find target named \"\(target)\" in \"\(projectPath)\""
        case .missingProject(let project):
            return "Unable to find project reference named \"\(project)\" in project.yml"
        }
    }
}

extension Scheme {
    public init(name: String, target: Target, targetScheme: TargetScheme, project: Project, debugConfig: String, releaseConfig: String) {
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
                language: targetScheme.language,
                region: targetScheme.region
            ),
            test: .init(
                config: debugConfig,
                gatherCoverageData: targetScheme.gatherCoverageData,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                commandLineArguments: targetScheme.commandLineArguments,
                targets: targetScheme.testTargets,
                environmentVariables: targetScheme.environmentVariables,
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
            )
        )
    }

    private static func buildTargets(for target: Target, project: Project) -> [BuildTarget] {
        let buildTarget = Scheme.BuildTarget(target: TargetReference.local(target.name))
        switch target.type {
        case .watchApp, .watch2App:
            let hostTarget = project.targets
                .first { projectTarget in
                    projectTarget.dependencies.contains { $0.reference == target.name }
                }
                .map { BuildTarget(target: TargetReference.local($0.name)) }
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
