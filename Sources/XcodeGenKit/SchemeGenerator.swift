import Foundation
import ProjectSpec
import XcodeProj

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
        return project.configs.first { $0.type == .debug }!
    }

    var defaultReleaseConfig: Config {
        return project.configs.first { $0.type == .release }!
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
        let pbxproj = try XcodeProj(pathString: reference.path).pbxproj
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
                        debugConfig: debugConfig.name,
                        releaseConfig: releaseConfig.name
                    )
                    let xcscheme = try generateScheme(scheme)
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
                            debugConfig: debugConfig.name,
                            releaseConfig: releaseConfig.name
                        )
                        let xcscheme = try generateScheme(scheme)
                        xcschemes.append(xcscheme)
                    }
                }
            }
        }

        return xcschemes
    }

    public func generateScheme(_ scheme: Scheme) throws -> XCScheme {

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

        let target = project.getTarget(scheme.build.targets.first!.target.name)
        let shouldExecuteOnLaunch = target?.type.isExecutable == true

        let buildableReference = buildActionEntries.first!.buildableReference
        let productRunable = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: buildActionEntries,
            preActions: scheme.build.preActions.map(getExecutionAction),
            postActions: scheme.build.postActions.map(getExecutionAction),
            parallelizeBuild: scheme.build.parallelizeBuild,
            buildImplicitDependencies: scheme.build.buildImplicitDependencies
        )

        let testables = zip(testTargets, testBuildTargetEntries).map { testTarget, testBuilEntries in
            XCScheme.TestableReference(
                skipped: false,
                parallelizable: testTarget.parallelizable,
                randomExecutionOrdering: testTarget.randomExecutionOrder,
                buildableReference: testBuilEntries.buildableReference,
                skippedTests: testTarget.skippedTests.map(XCScheme.SkippedTest.init)
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
            shouldUseLaunchSchemeArgsEnv: scheme.test?.shouldUseLaunchSchemeArgsEnv ?? true,
            codeCoverageEnabled: scheme.test?.gatherCoverageData ?? Scheme.Test.gatherCoverageDataDefault,
            codeCoverageTargets: coverageBuildableTargets,
            onlyGenerateCoverageForSpecifiedTargets: !coverageBuildableTargets.isEmpty,
            disableMainThreadChecker: scheme.test?.disableMainThreadChecker ?? Scheme.Test.disableMainThreadCheckerDefault,
            commandlineArguments: testCommandLineArgs,
            environmentVariables: testVariables,
            language: scheme.test?.language,
            region: scheme.test?.region
        )

        let launchAction = XCScheme.LaunchAction(
            runnable: shouldExecuteOnLaunch ? productRunable : nil,
            buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
            preActions: scheme.run?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.run?.postActions.map(getExecutionAction) ?? [],
            macroExpansion: shouldExecuteOnLaunch ? nil : buildableReference,
            selectedDebuggerIdentifier: (scheme.run?.debugEnabled ?? Scheme.Run.debugEnabledDefault) ? XCScheme.defaultDebugger : "",
            selectedLauncherIdentifier: (scheme.run?.debugEnabled ?? Scheme.Run.debugEnabledDefault) ? XCScheme.defaultLauncher : "Xcode.IDEFoundation.Launcher.PosixSpawn",
            disableMainThreadChecker: scheme.run?.disableMainThreadChecker ?? Scheme.Run.disableMainThreadCheckerDefault,
            commandlineArguments: launchCommandLineArgs,
            environmentVariables: launchVariables,
            language: scheme.run?.language,
            region: scheme.run?.region
        )

        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: productRunable,
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
            archiveAction: archiveAction
        )
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
    public init(name: String, target: Target, targetScheme: TargetScheme, debugConfig: String, releaseConfig: String) {
        self.init(
            name: name,
            build: .init(targets: [Scheme.BuildTarget(target: TargetReference.local(target.name))]),
            run: .init(
                config: debugConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions,
                environmentVariables: targetScheme.environmentVariables,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker
            ),
            test: .init(
                config: debugConfig,
                gatherCoverageData: targetScheme.gatherCoverageData,
                disableMainThreadChecker: targetScheme.disableMainThreadChecker,
                commandLineArguments: targetScheme.commandLineArguments,
                targets: targetScheme.testTargets,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions,
                environmentVariables: targetScheme.environmentVariables
            ),
            profile: .init(
                config: releaseConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions,
                environmentVariables: targetScheme.environmentVariables
            ),
            analyze: .init(
                config: debugConfig
            ),
            archive: .init(
                config: releaseConfig,
                preActions: targetScheme.preActions,
                postActions: targetScheme.postActions
            )
        )
    }
}
