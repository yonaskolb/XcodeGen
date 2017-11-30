import Foundation
import PathKit
import xcproj
import JSONUtilities
import Yams
import ProjectSpec

public class ProjectGenerator {

    let spec: ProjectSpec
    let currentXcodeVersion = "0900"

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
        let pbxProjGenerator = PBXProjGenerator(spec: spec, currentXcodeVersion: currentXcodeVersion)
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

    func generateScheme(_ scheme: Scheme, pbxProject: PBXProj, tests: [String] = []) throws -> XCScheme {

        func getBuildEntry(_ buildTarget: Scheme.BuildTarget) -> XCScheme.BuildAction.Entry {

            let targetReference = pbxProject.objects.nativeTargets.referenceValues.first { $0.name == buildTarget.target }!

            let buildableReference = XCScheme.BuildableReference(referencedContainer: "container:\(spec.name).xcodeproj", blueprintIdentifier: targetReference.reference, buildableName: "\(buildTarget.target).\(targetReference.productType!.fileExtension!)", blueprintName: scheme.name)

            return XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: buildTarget.buildTypes)
        }

        let testBuildTargets = tests.map {
            Scheme.BuildTarget(target: $0, buildTypes: BuildType.testOnly)
        }

        let testBuildTargetEntries = testBuildTargets.map(getBuildEntry)

        let buildActionEntries: [XCScheme.BuildAction.Entry] = scheme.build.targets.map(getBuildEntry) + testBuildTargetEntries

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
                                             codeCoverageEnabled: scheme.test?.gatherCoverageData ?? false,
                                             commandlineArguments: testCommandLineArgs)

        let launchAction = XCScheme.LaunchAction(buildableProductRunnable: productRunable,
                                                 buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name,
                                                 commandlineArguments: launchCommandLineArgs)

        let profileAction = XCScheme.ProfileAction(buildableProductRunnable: productRunable,
                                                   buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name,
                                                   commandlineArguments: profileCommandLineArgs)

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: scheme.analyze?.config ?? defaultDebugConfig.name)

        let archiveAction = XCScheme.ArchiveAction(buildConfiguration: scheme.archive?.config ?? defaultReleaseConfig.name, revealArchiveInOrganizer: true)

        return XCScheme(name: scheme.name,
                        lastUpgradeVersion: currentXcodeVersion,
                        version: "1.3",
                        buildAction: buildAction,
                        testAction: testAction,
                        launchAction: launchAction,
                        profileAction: profileAction,
                        analyzeAction: analyzeAction,
                        archiveAction: archiveAction)
    }

    func generateBreakpointList(_ breakpoints: [Breakpoint]) throws -> XCBreakpointList {
        return XCBreakpointList(type: "4", version: "2.0", breakpoints: try breakpoints.flatMap({ try generateBreakpointProxy($0) }))
    }

    private func generateBreakpointProxy(_ breakpoint: Breakpoint) throws -> XCBreakpointList.BreakpointProxy {
        var extensionID: XCBreakpointList.BreakpointProxy.BreakpointExtensionID
        switch breakpoint.extensionID {
            case "file": extensionID = .file
            case "exception": extensionID = .exception
            case "swiftError": extensionID = .swiftError
            case "openGLError": extensionID = .openGLError
            case "symbolic": extensionID = .symbolic
            case "ideConstraintError": extensionID = .ideConstraintError
            case "ideTestFailure": extensionID = .ideTestFailure
            default: throw SpecValidationError.ValidationError.invalidBreakpointExtensionID(breakpoint.extensionID)
        }

        let xcbreakpoint = XCBreakpointList.BreakpointProxy.BreakpointContent(enabled: breakpoint.enabled,
                                                                              ignoreCount: breakpoint.ignoreCount,
                                                                              continueAfterRunningActions: breakpoint.continueAfterRunningActions,
                                                                              filePath: breakpoint.filePath,
                                                                              timestamp: breakpoint.timestamp,
                                                                              startingColumn: breakpoint.startingColumn,
                                                                              endingColumn: breakpoint.endingColumn,
                                                                              startingLine: breakpoint.startingLine,
                                                                              endingLine: breakpoint.endingLine,
                                                                              breakpointStackSelectionBehavior: breakpoint.breakpointStackSelectionBehavior,
                                                                              symbol: breakpoint.symbol,
                                                                              module: breakpoint.module,
                                                                              scope: breakpoint.scope,
                                                                              stopOnStyle: breakpoint.stopOnStyle,
                                                                              actions: try breakpoint.actions.flatMap({ try generateBreakpointActionProxy($0) }),
                                                                              locations: breakpoint.locations.flatMap({ generateBreakpointLocationProxy($0) }))

        return XCBreakpointList.BreakpointProxy(breakpointExtensionID: extensionID, breakpointContent: xcbreakpoint)
    }

    private func generateBreakpointActionProxy(_ breakpointAction: Breakpoint.Action) throws -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy {
        var extensionID: XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
        switch breakpointAction.extensionID {
            case "debuggerCommand": extensionID = .debuggerCommand
            case "log": extensionID = .log
            case "shellCommand": extensionID = .shellCommand
            case "graphicsTrace": extensionID = .graphicsTrace
            case "appleScript": extensionID = .appleScript
            case "sound": extensionID = .sound
            case "openGLError": extensionID = .openGLError
            default: throw SpecValidationError.ValidationError.invalidBreakpointActionExtensionID(breakpointAction.extensionID)
        }

        let xcaction = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionContent(consoleCommand: breakpointAction.consoleCommand,
                                                                                                                        message: breakpointAction.message,
                                                                                                                        conveyanceType: breakpointAction.conveyanceType,
                                                                                                                        command: breakpointAction.command,
                                                                                                                        arguments: breakpointAction.arguments,
                                                                                                                        waitUntilDone: breakpointAction.waitUntilDone,
                                                                                                                        script: breakpointAction.script,
                                                                                                                        soundName: breakpointAction.soundName)

        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy(actionExtensionID: extensionID, actionContent: xcaction)
    }

    private func generateBreakpointLocationProxy(_ breakpointLocation: Breakpoint.Location) -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointLocationProxy {
        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointLocationProxy()
    }

    func generateSharedData(pbxProject: PBXProj) throws -> XCSharedData {
        var xcschemes: [XCScheme] = []

        for scheme in spec.schemes {
            let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
            xcschemes.append(xcscheme)
        }

        let xcbreakpointlist = try generateBreakpointList(spec.breakpoints)

        for target in spec.targets {
            if let scheme = target.scheme {

                if scheme.configVariants.isEmpty {
                    let schemeName = target.name

                    let debugConfig = spec.configs.first { $0.type == .debug }!
                    let releaseConfig = spec.configs.first { $0.type == .release }!

                    let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfig: debugConfig.name, releaseConfig: releaseConfig.name, gatherCoverageData: scheme.gatherCoverageData, commandLineArguments: scheme.commandLineArguments)
                    let scheme = try generateScheme(specScheme, pbxProject: pbxProject, tests: scheme.testTargets)
                    xcschemes.append(scheme)
                } else {
                    for configVariant in scheme.configVariants {

                        let schemeName = "\(target.name) \(configVariant)"

                        let debugConfig = spec.configs.first { $0.type == .debug && $0.name.contains(configVariant) }!
                        let releaseConfig = spec.configs.first { $0.type == .release && $0.name.contains(configVariant) }!

                        let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfig: debugConfig.name, releaseConfig: releaseConfig.name, gatherCoverageData: scheme.gatherCoverageData, commandLineArguments: scheme.commandLineArguments)
                        let scheme = try generateScheme(specScheme, pbxProject: pbxProject, tests: scheme.testTargets)
                        xcschemes.append(scheme)
                    }
                }
            }
        }

        return XCSharedData(schemes: xcschemes, breakpoints: xcbreakpointlist)
    }
}

