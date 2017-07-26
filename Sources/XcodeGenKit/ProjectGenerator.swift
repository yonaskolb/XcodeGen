//
//  Generator.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/5/17.
//
//

import Foundation
import PathKit
import xcodeproj
import xcodeprojprotocols
import JSONUtilities
import Yams

public class ProjectGenerator {

    var spec: Spec
    var path: Path
    let currentXcodeVersion = "0830"

    public init(spec: Spec, path: Path) {
        self.spec = spec
        self.path = path
    }

    public func generateProject() throws -> XcodeProj {
        let pbxProjGenerator = PBXProjGenerator(spec: spec, path: path)
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

    func generateSharedData(pbxProject: PBXProj) throws -> XCSharedData {
        var schemes: [XCScheme] = []

        for target in spec.targets {
            if target.generateSchemes {
                for variant in spec.configVariants {
                    let targetReference = pbxProject.objects.nativeTargets.first { $0.name == target.name }!
                    let schemeName = "\(target.name) \(variant)"
                    let debugConfig = "\(variant) \(spec.configs.first { $0.type == .debug }!)"
                    let releaseConfig = "\(variant) \(spec.configs.first { $0.type == .release }!)"

                    let buildableReference = XCScheme.BuildableReference(referencedContainer: "container:\(spec.name).xcodeproj", blueprintIdentifier: targetReference.reference, buildableName: "\(target.name).app", blueprintName: schemeName)

                    let buildActionEntry = XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: XCScheme.BuildAction.Entry.BuildFor.default)

                    let buildAction = XCScheme.BuildAction(buildActionEntries: [buildActionEntry], parallelizeBuild: true, buildImplicitDependencies: true)

                    let testAction = XCScheme.TestAction(buildConfiguration: debugConfig,  macroExpansion: buildableReference)

                    let buildableProductRunnable = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)

                    let launchAction = XCScheme.LaunchAction(buildableProductRunnable: buildableProductRunnable, buildConfiguration: debugConfig)

                    let profileAction = XCScheme.ProfileAction(buildableProductRunnable: buildableProductRunnable, buildConfiguration: releaseConfig)

                    let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: debugConfig)

                    let archiveAction = XCScheme.ArchiveAction(buildConfiguration: releaseConfig, revealArchiveInOrganizer: true)

                    let scheme = XCScheme(name: schemeName,
                                          lastUpgradeVersion: currentXcodeVersion,
                                          version: "1.3",
                                          buildAction: buildAction,
                                          testAction: testAction,
                                          launchAction: launchAction,
                                          profileAction: profileAction,
                                          analyzeAction: analyzeAction,
                                          archiveAction: archiveAction)
                    schemes.append(scheme)
                }
            }
        }
        
        return XCSharedData(schemes: schemes)
    }
}
