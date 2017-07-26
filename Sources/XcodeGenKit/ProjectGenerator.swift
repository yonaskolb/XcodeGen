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

    var defaultDebugConfig: Config {
        return spec.configs.first { $0.type == .debug }!
    }

    var defaultReleaseConfig: Config {
        return spec.configs.first { $0.type == .release }!
    }

    func validate() throws {

        let defaultConfigs = [Config(name: "Debug", type: .debug), Config(name: "Release", type: .release)]

        if !spec.configVariants.isEmpty  {
            spec.configs = defaultConfigs.reduce([]) { all, config in
                all + spec.configVariants.map { variant in
                    let name = "\(variant) \(config.name)"
                    return Config(name: name, type: config.type, buildSettingGroups: config.buildSettingGroups, buildSettings: config.buildSettings)
                }
            }
        } else if spec.configs.isEmpty {
            spec.configs = defaultConfigs
        }

        var errors: [SpecValidationError.Error] = []

        for target in spec.targets {
            for dependency in target.dependencies {
                if case .target(let target) = dependency, spec.getTarget(target) == nil {
                    errors.append(.invalidTargetDependency(target))
                }
            }
            if let buildSettings = target.buildSettings {
                for config in buildSettings.configSettings.keys {
                    if spec.getConfig(config) == nil {
                        errors.append(.invalidBuildSettingConfig(config))
                    }
                }
            }
            for source in target.sources {
                let sourcePath = path + source
                if !sourcePath.exists {
                    errors.append(.missingTargetSource(sourcePath.string))
                }
            }
        }

        for scheme in spec.schemes {
            for buildTarget in scheme.build.targets {
                if spec.getTarget(buildTarget.target) == nil {
                    errors.append(.invalidSchemeTarget(buildTarget.target))
                }
            }
            if let buildAction = scheme.run, spec.getConfig(buildAction.config) == nil  {
                errors.append(.invalidSchemeConfig(buildAction.config))
            }
            if let buildAction = scheme.test, spec.getConfig(buildAction.config) == nil  {
                errors.append(.invalidSchemeConfig(buildAction.config))
            }
            if let buildAction = scheme.profile, spec.getConfig(buildAction.config) == nil  {
                errors.append(.invalidSchemeConfig(buildAction.config))
            }
            if let buildAction = scheme.analyze, spec.getConfig(buildAction.config) == nil  {
                errors.append(.invalidSchemeConfig(buildAction.config))
            }
            if let buildAction = scheme.archive, spec.getConfig(buildAction.config) == nil  {
                errors.append(.invalidSchemeConfig(buildAction.config))
            }
        }

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }

    public func generateProject() throws -> XcodeProj {
        try validate()
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

    func generateScheme(_ scheme: Scheme, pbxProject: PBXProj) throws -> XCScheme {

        let buildActionEntries: [XCScheme.BuildAction.Entry] = scheme.build.targets.map { target in

            let targetReference = pbxProject.objects.nativeTargets.first { $0.name == target.target }!

            let buildableReference = XCScheme.BuildableReference(referencedContainer: "container:\(spec.name).xcodeproj", blueprintIdentifier: targetReference.reference, buildableName: "\(target.target).\(targetReference.productType!.fileExtension!)", blueprintName: scheme.name)

            return XCScheme.BuildAction.Entry(buildableReference: buildableReference, buildFor: XCScheme.BuildAction.Entry.BuildFor.default)
        }

        let buildableReference = buildActionEntries.first!.buildableReference
        let productRunabke = XCScheme.BuildableProductRunnable(buildableReference: buildableReference)

        let buildAction = XCScheme.BuildAction(buildActionEntries: buildActionEntries, parallelizeBuild: true, buildImplicitDependencies: true)

        let testAction = XCScheme.TestAction(buildConfiguration: scheme.test?.config ?? defaultDebugConfig.name,  macroExpansion: buildableReference)

        let launchAction = XCScheme.LaunchAction(buildableProductRunnable: productRunabke,
                                                 buildConfiguration: scheme.run?.config ?? defaultDebugConfig.name)

        let profileAction = XCScheme.ProfileAction(buildableProductRunnable: productRunabke,
                                                   buildConfiguration: scheme.profile?.config ?? defaultReleaseConfig.name)

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

    func generateSharedData(pbxProject: PBXProj) throws -> XCSharedData {
        var xcschemes: [XCScheme] = []

        for scheme in spec.schemes {
            let xcscheme = try generateScheme(scheme, pbxProject: pbxProject)
            xcschemes.append(xcscheme)
        }

        for target in spec.targets {
            if target.generateSchemes {
                for variant in spec.configVariants {
                    let schemeName = "\(target.name) \(variant)"

                    let debugConfig = spec.configs.first { $0.type == .debug && $0.name.contains(variant) }!
                    let releaseConfig = spec.configs.first { $0.type == .release && $0.name.contains(variant) }!

                    let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfig: debugConfig.name, releaseConfig: releaseConfig.name)
                    let scheme = try generateScheme(specScheme, pbxProject: pbxProject)
                    xcschemes.append(scheme)
                }
            }
        }

        return XCSharedData(schemes: xcschemes)
    }
}

public struct SpecValidationError: Error, CustomStringConvertible {

    public var errors: [Error]

    public enum Error: CustomStringConvertible {
        case invalidTargetDependency(String)
        case invalidSchemeTarget(String)
        case invalidSchemeConfig(String)
        case invalidBuildSettingConfig(String)
        case missingTargetSource(String)

        public var description: String {
            switch self {
            case let .invalidTargetDependency(dependency): return "Target has invalid dependency: \(dependency)"
            case let .invalidSchemeTarget(target): return "Scheme has invalid build target: \(target)"
            case let .invalidSchemeConfig(config): return "Scheme has invalid build configuration: \(config)"
            case let .invalidBuildSettingConfig(config): return "Build setting has invalid build configuration: \(config)"
            case let .missingTargetSource(source): return "Target has a missing source directory: \(source)"
            }
        }
    }

    public var description: String {
        let title: String
        if errors.count == 1 {
            title = "Spec validation error: "
        } else {
            title = "\(errors.count) Spec validations errors:\n"
        }
        return "\(title)" + errors.map { $0.description }.joined(separator: "\n")
    }
}
