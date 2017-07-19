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
        let workspaceData = XCWorkspace.Data(path: path + "project.xcworkspace/contents.xcworkspacedata", references: workspaceReferences)
        let workspace = XCWorkspace(path: path + "project.xcworkspace", data: workspaceData)

        var objects: [PBXObject] = []
        var ids = 0

        func id() -> String {
            ids += 1
            return ids.description.md5().uppercased()
//            return "OBJECT_\(ids)"
        }

        let mainGroup = PBXGroup(reference: id(), children: [], sourceTree: .group)

        let buildConfigs = spec.configs.map { config in

            XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: nil, buildSettings: BuildSettings(dictionary: config.settings))
        }
        let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: Set(buildConfigs.map { $0.reference }), defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)


        objects += buildConfigs.map { .xcBuildConfiguration($0) }
        objects.append(.xcConfigurationList(buildConfigList))

        var targets: [String] = []
        for target in spec.targets {
            let sourcePaths: [Path] = try target.sources.reduce([]) { paths, source in
//                $0 + spec.path.parent().glob($1)
                let sourcePaths = spec.path.parent() + source
                let sourceFiles = try sourcePaths.recursiveChildren().filter { $0.isFile }
                return paths + sourceFiles
            }
            let fileReferences = sourcePaths.map { PBXFileReference(reference: id(), sourceTree: .group, path: $0.lastComponent) }
            let buildFiles = fileReferences.map { PBXBuildFile(reference: id(), fileRef: $0.reference) }
            let buildPhase = PBXSourcesBuildPhase(reference: id(), files: Set(buildFiles.map { $0.reference }))
            let buildPhases = [buildPhase]

            let productReference = PBXFileReference(reference: id(), sourceTree: .buildProductsDir, path: target.name, includeInIndex: 0)

            let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: [], defaultConfigurationName: "")
            let nativeTarget = PBXNativeTarget(reference: id(), buildConfigurationList: buildConfigList.reference, buildPhases: buildPhases.map{ $0.reference }, buildRules: [], dependencies: [], name: target.name, productReference: productReference.reference, productType: target.type)

            objects += buildFiles.map { .pbxBuildFile($0) }
            objects += fileReferences.map { .pbxFileReference($0) }
            objects += buildPhases.map { .pbxSourcesBuildPhase($0) }

            objects.append(.xcConfigurationList(buildConfigList))
            objects.append(.pbxNativeTarget(nativeTarget))
            objects.append(.pbxFileReference(productReference))

            targets.append(nativeTarget.reference)
        }

        let pbxProjectRoot = PBXProject(reference: id(), buildConfigurationList: buildConfigList.reference, compatibilityVersion: "Xcode 3.2", mainGroup: mainGroup.reference, targets: targets)
        objects.append(.pbxProject(pbxProjectRoot))

        let pbxProject = PBXProj(path: path + "project.pbxproj", name: "Generated_Project", archiveVersion: 1, objectVersion: 46, rootObject: pbxProjectRoot.reference, objects: objects)

        let schemes: [XCScheme] = spec.schemes.map { schemeSpec in
//            let buildEntries: [XCScheme.BuildAction.Entry] = schemeSpec.build.entries.map { build in
//                let buildableReference: XCScheme.BuildableReference? = nil
//                return XCScheme.BuildAction.Entry(buildableReference: buildableReference!, buildFor: build.buildTypes)
//            }
            let buildAction = XCScheme.BuildAction(buildActionEntries: [], parallelizeBuild: true, buildImplicitDependencies: true)

            return XCScheme(path: path + "xcshareddata/xcschemes/\(schemeSpec.name)", lastUpgradeVersion: nil, version: nil, buildAction: buildAction, testAction: nil, launchAction: nil, profileAction: nil, analyzeAction: nil, archiveAction: nil)
        }

        let sharedData = XCSharedData(path: path + "xcshareddata", schemes: schemes)
        let project = XcodeProj(path: path, workspace: workspace, pbxproj: pbxProject, sharedData: sharedData)

        try project.write(override: true)
    }
}

extension XcodeProj: Writable {

    public func write(override: Bool) throws {
        if override && path.exists {
            try path.delete()
        }

        // write workspace
//        try workspace.data.path.mkpath()
//        try workspace.data.write(override: true)

        // write pbxproj
        try pbxproj.path.mkpath()
        try pbxproj.write(override: override)

        // write shared data
        if let sharedData = sharedData {
            for scheme in sharedData.schemes {
                try scheme.path.mkpath()
                try scheme.write(override: override)
            }
        }
    }
}
