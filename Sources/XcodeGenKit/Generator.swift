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

public struct Generator {

    public static func generate(spec: Spec, path: Path) throws {

        let workspaceReferences: [XCWorkspace.Data.FileRef] = [XCWorkspace.Data.FileRef.project(path: path)]
        let workspaceData = XCWorkspace.Data(path: path, references: workspaceReferences)
        let workspace = XCWorkspace(path: path + "project.xcworkspace", data: workspaceData)


        var objects: [PBXObject] = []
        var ids = 0

        func id() -> String {
            ids += 1
            return "OBJECT_\(ids)"
        }

        for target in spec.targets {
            let sourcePaths: [Path] = target.sources.reduce([]) { paths, source in
//                $0 + spec.path.parent().glob($1)
                let sourcePaths = try! (spec.path.parent() + source).recursiveChildren().filter { $0.isFile }
                return paths + sourcePaths
            }
            let fileReferences = sourcePaths.map { PBXFileReference(reference: id(), sourceTree: .group, path: $0.lastComponent) }
            let buildFiles = fileReferences.map { PBXBuildFile(reference: id(), fileRef: $0.reference) }
            let buildPhase = PBXSourcesBuildPhase(reference: id(), files: Set(buildFiles.map { $0.reference }))
            let buildPhases = [buildPhase]

            let nativeTarget = PBXNativeTarget(reference: "OBJECT_\(objects.count)", buildConfigurationList: "234", buildPhases: buildPhases.map{ $0.reference }, buildRules: [], dependencies: [], name: target.name)

            objects += buildFiles.map { .pbxBuildFile($0) }
            objects += fileReferences.map { .pbxFileReference($0) }
            objects += buildPhases.map { .pbxSourcesBuildPhase($0) }
            
            objects.append(.pbxNativeTarget(nativeTarget))
        }

        let pbxProject = PBXProj(path: path + "project.pbxproj", name: "Generated_Project", archiveVersion: 1, objectVersion: 46, rootObject: "12345", objects: objects)

        let schemes: [XCScheme] = spec.schemes.map { schemeSpec in
//            let buildEntries: [XCScheme.BuildAction.Entry] = schemeSpec.build.entries.map { build in
//                let buildableReference: XCScheme.BuildableReference? = nil
//                return XCScheme.BuildAction.Entry(buildableReference: buildableReference!, buildFor: build.buildTypes)
//            }
            let buildAction = XCScheme.BuildAction(buildActionEntries: [], parallelizeBuild: true, buildImplicitDependencies: true)

            return XCScheme(path: path, lastUpgradeVersion: nil, version: nil, buildAction: buildAction, testAction: nil, launchAction: nil, profileAction: nil, analyzeAction: nil, archiveAction: nil)
        }

        let sharedData = XCSharedData(path: path, schemes: schemes)
        let project = XcodeProj(path: path, workspace: workspace, pbxproj: pbxProject, sharedData: sharedData)

        try project.write(override: true)
    }
}

extension XcodeProj: Writable {

    public func write(override: Bool) throws {
        if override && path.exists {
            try path.delete()
        }
        
        try path.mkpath()
        try pbxproj.write(override: override)
    }
}
