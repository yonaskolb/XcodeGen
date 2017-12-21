import Foundation
import PathKit
import xcproj
import JSONUtilities
import Yams
import ProjectSpec

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
        let workspaceReferences: [XCWorkspace.Data.FileRef] = [XCWorkspace.Data.FileRef.project(path: Path(""))]
        let workspaceData = XCWorkspace.Data(references: workspaceReferences)
        return XCWorkspace(data: workspaceData)
    }

    func generateScheme(_ scheme: Scheme, pbxProject: PBXProj) throws -> XCScheme {

        func getBuildEntry(_ buildTarget: Scheme.BuildTarget) -> XCScheme.BuildAction.Entry {

            let predicate: (PBXTarget) -> Bool = { $0.name == buildTarget.target }
            let targetReference = pbxProject.objects.nativeTargets.referenceValues.first{ predicate($0 as PBXTarget) } ?? pbxProject.objects.legacyTargets.referenceValues.first{ predicate($0 as PBXTarget) }!

            let buildableReference = XCScheme.BuildableReference(referencedContainer: "container:\(spec.name).xcodeproj", blueprintIdentifier: targetReference.reference, buildableName: buildTarget.target + (targetReference.productType?.fileExtension.map{ ".\($0)" } ?? ""), blueprintName: scheme.name)

            return XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: buildTarget.buildTypes)
        }

        let testTargetNames = scheme.test?.targets ?? []
        let testBuildTargets = testTargetNames.map {
            Scheme.BuildTarget(target: $0, buildTypes: BuildType.testOnly)
        }

        let testBuildTargetEntries = testBuildTargets.map(getBuildEntry)

        let buildActionEntries: [XCScheme.BuildAction.Entry] = scheme.build.targets.map(getBuildEntry)

        let buildableReference = buildActionEntries.first!.buildableReference
        let productRunable = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)

        let buildAction = XCScheme.BuildAction(buildActionEntries: buildActionEntries, parallelizeBuild: true, buildImplicitDependencies: true)

        let testables = testBuildTargetEntries.map { XCScheme.TestableReference(skipped: false, buildableReference: $0.buildableReference) }

        let testCommandLineArgs = scheme.test.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let launchCommandLineArgs = scheme.run.map { XCScheme.CommandLineArguments($0.commandLineArguments) }
        let profileCommandLineArgs = scheme.profile.map { XCScheme.CommandLineArguments($0.commandLineArguments) }

        let testAction = XCScheme.TestAction(buildConfiguration: scheme.test?.config ?? defaultDebugConfig.name,
                                             macroExpansion: buildableReference,
                                             testables: testables,
                                             shouldUseLaunchSchemeArgsEnv: scheme.test?.commandLineArguments.isEmpty ?? true,
                                             codeCoverageEnabled: scheme.test?.gatherCoverageData ?? false,
                                             commandlineArguments: testCommandLineArgs)

        let launchAction = XCScheme.LaunchAction(buildableProductRunnable: productRunable,
                                                 buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
                                                 commandlineArguments: launchCommandLineArgs)

        let profileAction = XCScheme.ProfileAction(buildableProductRunnable: productRunable,
                                                   buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name,
                                                   shouldUseLaunchSchemeArgsEnv: scheme.profile?.commandLineArguments.isEmpty ?? true,
                                                   commandlineArguments: profileCommandLineArgs)

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: scheme.analyze?.config ?? defaultDebugConfig.name)

        let archiveAction = XCScheme.ArchiveAction(buildConfiguration: scheme.archive?.config ?? defaultReleaseConfig.name, revealArchiveInOrganizer: true)

        return XCScheme(name: scheme.name,
                        lastUpgradeVersion: spec.xcodeVersion,
                        version: "1.3",
                        buildAction: buildAction,
                        testAction: testAction,
                        launchAction: launchAction,
                        profileAction: profileAction,
                        analyzeAction: analyzeAction,
                        archiveAction: archiveAction)
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

                    let scheme = Scheme(name: schemeName, target: target, targetScheme: targetScheme, debugConfig: debugConfig.name, releaseConfig: releaseConfig.name)
                    let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
                    xcschemes.append(xcscheme)
                } else {
                    for configVariant in targetScheme.configVariants {

                        let schemeName = "\(target.name) \(configVariant)"

                        let debugConfig = spec.configs.first { $0.type == .debug && $0.name.contains(configVariant) }!
                        let releaseConfig = spec.configs.first { $0.type == .release && $0.name.contains(configVariant) }!

                        let scheme = Scheme(name: schemeName, target: target, targetScheme: targetScheme, debugConfig: debugConfig.name, releaseConfig: releaseConfig.name)
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
            run: .init(config: debugConfig, commandLineArguments: targetScheme.commandLineArguments),
            test: .init(config: debugConfig, gatherCoverageData: targetScheme.gatherCoverageData, commandLineArguments: targetScheme.commandLineArguments, targets: targetScheme.testTargets),
            profile: .init(config: releaseConfig, commandLineArguments: targetScheme.commandLineArguments),
            analyze: .init(config: debugConfig),
            archive: .init(config: releaseConfig)
        )
    }
}

