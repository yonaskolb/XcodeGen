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

    let spec: Spec
    let path: Path

    var groups: [PBXGroup] = []
    var fileReferences: [PBXFileReference] = []
    var groupsByPath: [String: String] = [:]

    var targetNativeReferences: [String: String] = [:]
    var targetBuildFileReferences: [String: String] = [:]
    var targetFileReferences: [String: String] = [:]

    var ids = 0
    var projectReference: String

    var buildSettingGroups: [String: BuildSettings] = [:]

    enum BuildSettingGroupType {
        case config(ConfigType)
        case platform(Platform)
        case product(PBXProductType)
        case base

        var path: String {
            switch self {
            case let .config(config): return "configs/\(config.rawValue)"
            case let .platform(platform): return "platforms/\(platform.rawValue)"
            case let .product(product): return "products/\(product.rawValue)"
            case .base: return "base"
            }
        }
    }

    func getBuildSettingGroup(_ type: BuildSettingGroupType) throws -> BuildSettings? {
        if let group = buildSettingGroups[type.path] {
            return group
        }
        let path = Path(#file).parent().parent().parent() + "setting_groups/\(type.path).yml"
        guard path.exists else { return nil }
        let content: String = try path.read()
        let yaml = try Yams.load(yaml: content)
        let buildSettings = BuildSettings(dictionary: yaml as! JSONDictionary)
        buildSettingGroups[type.path] = buildSettings
        return buildSettings
    }

    public init(spec: Spec, path: Path) {
        self.spec = spec
        self.path = path
        projectReference = ""
        projectReference = id()
    }

    func id() -> String {
        ids += 1
//        return ids.description.md5().uppercased()
        return "OBJECT_\(ids)"
    }

    public func generate() throws -> XcodeProj {
        let pbxProject = try generatePBXProj()
        let workspace = try generateWorkspace()
        let sharedData = try generateSharedData()
        return XcodeProj(path: path, workspace: workspace, pbxproj: pbxProject, sharedData: sharedData)
    }

    func generatePBXProj() throws -> PBXProj {
        var objects: [PBXObject] = []

        let buildConfigs = spec.configs.map { config in
            XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: nil, buildSettings: config.buildSettings)
        }
        let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: buildConfigs.referenceSet, defaultConfigurationName: buildConfigs.first?.name ?? "", defaultConfigurationIsVisible: 0)

        objects += buildConfigs.map { .xcBuildConfiguration($0) }
        objects.append(.xcConfigurationList(buildConfigList))

        var topLevelGroups: [PBXGroup] = []

        for target in spec.targets {
            targetNativeReferences[target.name] = id()

            let fileReference = PBXFileReference(reference: id(), sourceTree: .buildProductsDir, explicitFileType: target.type.fileExtension, path: target.filename, includeInIndex: 0)
            objects.append(.pbxFileReference(fileReference))
            targetFileReferences[target.name] = fileReference.reference

            let buildFile = PBXBuildFile(reference: id(), fileRef: fileReference.reference)
            objects.append(.pbxBuildFile(buildFile))
            targetBuildFileReferences[target.name] = buildFile.reference
        }

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

            let configs: [XCBuildConfiguration] = try spec.configs.map { config in
                let buildSettings = try getTargetBuildSettings(config: config, target: target)
                return XCBuildConfiguration(reference: id(), name: config.name, baseConfigurationReference: nil, buildSettings: buildSettings)
            }
            objects += configs.map { .xcBuildConfiguration($0) }
            let buildConfigList = XCConfigurationList(reference: id(), buildConfigurations: configs.referenceSet, defaultConfigurationName: "")
            objects.append(.xcConfigurationList(buildConfigList))

            var dependancies: [String] = []
            var frameworkFiles: [String] = []
            var copyFiles: [String] = []
            for dependancy in target.dependencies {
                switch dependancy.type {
                case .target:
                    let targetProxy = PBXContainerItemProxy(reference: id(), containerPortal: projectReference, remoteGlobalIDString: targetNativeReferences[dependancy.name]!, proxyType: .nativeTarget, remoteInfo: dependancy.name)
                    let targetDependancy = PBXTargetDependency(reference: id(), target: targetNativeReferences[dependancy.name]!, targetProxy: targetProxy.reference )

                    objects.append(.pbxContainerItemProxy(targetProxy))
                    objects.append(.pbxTargetDependency(targetDependancy))
                    dependancies.append(targetDependancy.reference)

                    let dependencyBuildFile = targetBuildFileReferences[dependancy.name]!
                    frameworkFiles.append(dependencyBuildFile)
                    copyFiles.append(dependencyBuildFile)
                case .system:
                    //TODO: handle system frameworks
                    break
                }
            }

            let fileReference = targetFileReferences[target.name]!
            if target.type == .framework {
                let buildFile = PBXBuildFile(reference: targetBuildFileReferences[target.name]!, fileRef: fileReference)
                objects.append(.pbxBuildFile(buildFile))
            }

            var buildPhases: [String] = []

            let buildPhase = PBXSourcesBuildPhase(reference: id(), files: buildFiles.referenceSet)
            objects.append(.pbxSourcesBuildPhase(buildPhase))
            buildPhases.append(buildPhase.reference)

            let frameworkPhase = PBXFrameworksBuildPhase(reference: id(), files: Set(frameworkFiles), runOnlyForDeploymentPostprocessing: 0)
            objects.append(.pbxFrameworksBuildPhase(frameworkPhase))
            buildPhases.append(frameworkPhase.reference)

            let copyPhase = PBXCopyFilesBuildPhase(reference: id(), dstPath: "", dstSubfolderSpec: .frameworks, files: Set(copyFiles))
            objects.append(.pbxCopyFilesBuildPhase(copyPhase))
            buildPhases.append(copyPhase.reference)

            let nativeTarget = PBXNativeTarget(
                reference: targetNativeReferences[target.name]!,
                buildConfigurationList: buildConfigList.reference,
                buildPhases: buildPhases,
                buildRules: [],
                dependencies: dependancies,
                name: target.name,
                productReference: fileReference,
                productType: target.type)
            objects.append(.pbxNativeTarget(nativeTarget))
        }

        let productGroup = PBXGroup(reference: id(), children: Set(targetFileReferences.values), sourceTree: .group, name: "Products")
        objects.append(.pbxGroup(productGroup))
        topLevelGroups.append(productGroup)

        let mainGroup = PBXGroup(reference: id(), children: topLevelGroups.referenceSet, sourceTree: .group)
        objects.append(.pbxGroup(mainGroup))

        let pbxProjectRoot = PBXProject(reference: projectReference, buildConfigurationList: buildConfigList.reference, compatibilityVersion: "Xcode 3.2", mainGroup: mainGroup.reference, targets: Array(targetNativeReferences.values))
        objects.append(.pbxProject(pbxProjectRoot))

        return PBXProj(path: path + "project.pbxproj", name: path.lastComponentWithoutExtension, archiveVersion: 1, objectVersion: 46, rootObject: projectReference, objects: objects)
    }

    func getTargetBuildSettings(config: Config, target: Target) throws -> BuildSettings {
        var buildSettings = BuildSettings()

        buildSettings += try getBuildSettingGroup(.base)
        if let configType = config.type {
            buildSettings += try getBuildSettingGroup(.config(configType))
        }
        buildSettings += try getBuildSettingGroup(.platform(target.platform))
        buildSettings += try getBuildSettingGroup(.product(target.type))
        buildSettings += target.buildSettings?.buildSettings
        buildSettings += target.buildSettings?.configSettings[config.name]

        return buildSettings
    }

    func getGroup(path: Path) throws -> PBXGroup {

        let directories = try path.children().filter { $0.isDirectory && $0.extension == nil }
        let files = try path.children().filter { $0.isFile || $0.extension != nil }
        var children: [String] = []

        let fileReferences = files.map { path in
            PBXFileReference(reference: id(), sourceTree: .group, path: path.lastComponent)
        }

        self.fileReferences += fileReferences
        children += fileReferences.referenceList

        for path in directories {
            let group = try getGroup(path: path)
            children.append(group.reference)
        }

        let group = PBXGroup(reference: id(), children: Set(children), sourceTree: .group, name: path.lastComponent, path: path.lastComponent)
        groups.append(group)
        return group
    }

    func generateWorkspace() throws -> XCWorkspace {
        let workspaceReferences: [XCWorkspace.Data.FileRef] = [XCWorkspace.Data.FileRef.project(path: Path(""))]
        let workspaceData = XCWorkspace.Data(path: path + "project.xcworkspace/contents.xcworkspacedata", references: workspaceReferences)
        return XCWorkspace(path: path + "project.xcworkspace", data: workspaceData)
    }

    func generateSharedData() throws -> XCSharedData {
        let schemes: [XCScheme] = spec.schemes.map { schemeSpec in
            //            let buildEntries: [XCScheme.BuildAction.Entry] = schemeSpec.build.entries.map { build in
            //                let buildableReference: XCScheme.BuildableReference? = nil
            //                return XCScheme.BuildAction.Entry(buildableReference: buildableReference!, buildFor: build.buildTypes)
            //            }
            let buildAction = XCScheme.BuildAction(buildActionEntries: [], parallelizeBuild: true, buildImplicitDependencies: true)

            return XCScheme(path: path + "xcshareddata/xcschemes/\(schemeSpec.name)", lastUpgradeVersion: nil, version: nil, buildAction: buildAction, testAction: nil, launchAction: nil, profileAction: nil, analyzeAction: nil, archiveAction: nil)
        }

        return XCSharedData(path: path + "xcshareddata", schemes: schemes)
    }
}

extension XcodeProj: Writable {

    public func write(override: Bool) throws {
        if override && path.exists {
            try path.delete()
        }

        // write workspace
        try workspace.data.path.mkpath()
        try workspace.data.write(override: override)

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
