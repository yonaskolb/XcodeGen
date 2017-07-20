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

public class ProjectGenerator {

    let spec: Spec
    let path: Path

    public init(spec: Spec, path: Path) {
        self.spec = spec
        self.path = path
    }

    public func generate() throws -> XcodeProj {

        let workspaceReferences: [XCWorkspace.Data.FileRef] = [XCWorkspace.Data.FileRef.project(path: path)]
        let workspaceData = XCWorkspace.Data(path: path + "project.xcworkspace/contents.xcworkspacedata", references: workspaceReferences)
        let workspace = XCWorkspace(path: path + "project.xcworkspace", data: workspaceData)

        var objects: [PBXObject] = []
        var groupsByPath: [String: String] = [:]
        var ids = 0

        func id() -> String {
            ids += 1
            return ids.description.md5().uppercased()
//            return "OBJECT_\(ids)"
        }

        let buildConfigs = spec.configs.map { config in

            XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: nil, buildSettings: BuildSettings(dictionary: config.settings))
        }
        let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: buildConfigs.referenceSet, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)


        objects += buildConfigs.map { .xcBuildConfiguration($0) }
        objects.append(.xcConfigurationList(buildConfigList))


        var groups: [PBXGroup] = []
        var fileReferences: [PBXFileReference] = []
        var topLevelGroups: [PBXGroup] = []

        func getGroup(path: Path) throws -> PBXGroup {

            let directories = try path.children().filter { $0.isDirectory }
            let files = try path.children().filter { $0.isFile }
            var children: [String] = []

            for path in files {
                let fileReference = PBXFileReference(reference: id(), sourceTree: .group, path: path.lastComponent)
                fileReferences.append(fileReference)
                children.append(fileReference.reference)
            }

            for path in directories {
                let group = try getGroup(path: path)
                children.append(group.reference)
            }

            let group = PBXGroup(reference: id(), children: Set(children), sourceTree: .group, name: path.lastComponent, path: path.lastComponent)
            groups.append(group)
            return group
        }

        var targets: [String] = []
        for target in spec.targets {
            let source = spec.path.parent() + target.sources.first!

            groups = []
            fileReferences = []
            let sourceGroup = try getGroup(path: source)
            topLevelGroups.append(sourceGroup)
            objects += groups.map { .pbxGroup($0) }
            objects += fileReferences.map { .pbxFileReference($0) }

            let buildFiles = fileReferences.map { PBXBuildFile(reference: id(), fileRef: $0.reference) }
            objects += buildFiles.map { .pbxBuildFile($0) }
            let buildPhase = PBXSourcesBuildPhase(reference: id(), files: buildFiles.referenceSet)
            let buildPhases = [buildPhase]
            objects += buildPhases.map { .pbxSourcesBuildPhase($0) }


            let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: [], defaultConfigurationName: "")
            objects.append(.xcConfigurationList(buildConfigList))


            let productReference = PBXFileReference(reference: id(), sourceTree: .buildProductsDir, path: target.name, includeInIndex: 0)
            objects.append(.pbxFileReference(productReference))

            let nativeTarget = PBXNativeTarget(reference: id(), buildConfigurationList: buildConfigList.reference, buildPhases: buildPhases.referenceList, buildRules: [], dependencies: [], name: target.name, productReference: productReference.reference, productType: target.type)
            objects.append(.pbxNativeTarget(nativeTarget))

            targets.append(nativeTarget.reference)
        }

        let mainGroup = PBXGroup(reference: id(), children: topLevelGroups.referenceSet, sourceTree: .group)
        objects.append(.pbxGroup(mainGroup))

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

        return project
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
