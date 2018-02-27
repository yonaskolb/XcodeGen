import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcproj
import Yams

public class ProjectGenerator {

    let spec: ProjectSpec

    public init(spec: ProjectSpec) {
        self.spec = spec
    }

    var defaultDebugConfig: Config {
        return spec.configs.first { $0.type == .debug }!
    }

    var defaultReleaseConfig: Config {
        return spec.configs.first { $0.type == .release }!
    }

    public func generateProject() throws -> XcodeProj {
        try spec.validate()
        let pbxProjGenerator = PBXProjGenerator(spec: spec)
        let pbxProject = try pbxProjGenerator.generate()
        let workspace = try generateWorkspace()
        let sharedData = try generateSharedData(pbxProject: pbxProject)
        return XcodeProj(workspace: workspace, pbxproj: pbxProject, sharedData: sharedData)
    }

    func generateWorkspace() throws -> XCWorkspace {
        let dataElement: XCWorkspaceDataElement = .file(XCWorkspaceDataFileRef(location: .self("")))
        let workspaceData = XCWorkspaceData(children: [dataElement])
        return XCWorkspace(data: workspaceData)
    }

    func generateScheme(_ scheme: Scheme, pbxProject: PBXProj) throws -> XCScheme {

        func getBuildEntry(_ buildTarget: Scheme.BuildTarget) -> XCScheme.BuildAction.Entry {

            let targetReference = pbxProject.objects.targets(named: buildTarget.target).first!
            let target = spec.getTarget(buildTarget.target)!
            let buildableReference = XCScheme.BuildableReference(
                referencedContainer: "container:\(spec.name).xcodeproj",
                blueprintIdentifier: targetReference.reference,
                buildableName: target.filename,
                blueprintName: buildTarget.target
            )

            return XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: buildTarget.buildTypes)
        }

        let testTargetNames = scheme.test?.targets ?? []
        let testBuildTargets = testTargetNames.map {
            Scheme.BuildTarget(target: $0, buildTypes: BuildType.testOnly)
        }

        let testBuildTargetEntries = testBuildTargets.map(getBuildEntry)

        let buildActionEntries: [XCScheme.BuildAction.Entry] = scheme.build.targets.map(getBuildEntry)

        func getExecutionAction(_ action: Scheme.ExecutionAction) -> XCScheme.ExecutionAction {
            // ExecutionActions can require the use of build settings. Xcode allows the settings to come from a build or test target.
            let environmentBuildable = action.settingsTarget.flatMap { settingsTarget in
                return (buildActionEntries + testBuildTargetEntries)
                    .first { settingsTarget == $0.buildableReference.blueprintName }?
                    .buildableReference
            }
            return XCScheme.ExecutionAction(scriptText: action.script, title: action.name, environmentBuildable: environmentBuildable)
        }

        let buildableReference = buildActionEntries.first!.buildableReference
        let productRunable = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: buildActionEntries,
            preActions: scheme.build.preActions.map(getExecutionAction),
            postActions: scheme.build.postActions.map(getExecutionAction),
            parallelizeBuild: scheme.build.parallelizeBuild,
            buildImplicitDependencies: scheme.build.buildImplicitDependencies
        )

        let testables = testBuildTargetEntries.map {
            XCScheme.TestableReference(skipped: false, buildableReference: $0.buildableReference)
        }

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
            shouldUseLaunchSchemeArgsEnv: testCommandLineArgs == nil && testVariables == nil,
            codeCoverageEnabled: scheme.test?.gatherCoverageData ?? false,
            commandlineArguments: testCommandLineArgs,
            environmentVariables: testVariables,
            language: ""
        )

        let launchAction = XCScheme.LaunchAction(
            buildableProductRunnable: productRunable,
            buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
            preActions: scheme.run?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.run?.postActions.map(getExecutionAction) ?? [],
            commandlineArguments: launchCommandLineArgs,
            environmentVariables: launchVariables
        )

        let profileAction = XCScheme.ProfileAction(
            buildableProductRunnable: productRunable,
            buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name,
            preActions: scheme.profile?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.profile?.postActions.map(getExecutionAction) ?? [],
            shouldUseLaunchSchemeArgsEnv: profileCommandLineArgs == nil && profileVariables == nil,
            commandlineArguments: profileCommandLineArgs,
            environmentVariables: profileVariables
        )

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: scheme.analyze?.config ?? defaultDebugConfig.name)

        let archiveAction = XCScheme.ArchiveAction(
            buildConfiguration: scheme.archive?.config ?? defaultReleaseConfig.name,
            revealArchiveInOrganizer: true,
            preActions: scheme.archive?.preActions.map(getExecutionAction) ?? [],
            postActions: scheme.archive?.postActions.map(getExecutionAction) ?? []
        )

        return XCScheme(
            name: scheme.name,
            lastUpgradeVersion: spec.xcodeVersion,
            version: spec.schemeVersion,
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction
        )
    }

    func generateSharedData(pbxProject: PBXProj) throws -> XCSharedData {
        var xcschemes: [XCScheme] = []

        for scheme in spec.schemes {
            let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
            xcschemes.append(xcscheme)
        }

        for target in spec.targets {
            if let targetScheme = target.scheme {

                if targetScheme.configVariants.isEmpty {
                    let schemeName = target.name

                    let debugConfig = spec.configs.first { $0.type == .debug }!
                    let releaseConfig = spec.configs.first { $0.type == .release }!

                    let scheme = Scheme(
                        name: schemeName,
                        target: target,
                        targetScheme: targetScheme,
                        debugConfig: debugConfig.name,
                        releaseConfig: releaseConfig.name
                    )
                    let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
                    xcschemes.append(xcscheme)
                } else {
                    for configVariant in targetScheme.configVariants {

                        let schemeName = "\(target.name) \(configVariant)"

                        let debugConfig = spec.configs
                            .first { $0.type == .debug && $0.name.contains(configVariant) }!
                        let releaseConfig = spec.configs
                            .first { $0.type == .release && $0.name.contains(configVariant) }!

                        let scheme = Scheme(
                            name: schemeName,
                            target: target,
                            targetScheme: targetScheme,
                            debugConfig: debugConfig.name,
                            releaseConfig: releaseConfig.name
                        )
                        let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
                        xcschemes.append(xcscheme)
                    }
                }
            }
        }

        return XCSharedData(schemes: xcschemes)
    }
}

extension Scheme {
    public init(name: String, target: Target, targetScheme: TargetScheme, debugConfig: String, releaseConfig: String) {
        self.init(
            name: name,
            build: .init(targets: [Scheme.BuildTarget(target: target.name)]),
            run: .init(
                config: debugConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables
            ),
            test: .init(
                config: debugConfig,
                gatherCoverageData: targetScheme.gatherCoverageData,
                commandLineArguments: targetScheme.commandLineArguments,
                targets: targetScheme.testTargets,
                environmentVariables: targetScheme.environmentVariables
            ),
            profile: .init(
                config: releaseConfig,
                commandLineArguments: targetScheme.commandLineArguments,
                environmentVariables: targetScheme.environmentVariables
            ),
            analyze: .init(config: debugConfig),
            archive: .init(config: releaseConfig)
        )
    }
}
