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
import ProjectSpec

public class ProjectGenerator {

    var spec: ProjectSpec
    var path: Path
    let currentXcodeVersion = "0830"

    public init(spec: ProjectSpec, path: Path) {
        self.spec = spec
        self.path = path
    }

    var defaultDebugConfig: Config {
        return spec.configs.first { $0.type == .debug }!
    }

    var defaultReleaseConfig: Config {
        return spec.configs.first { $0.type == .release }!
    }

    func getPath(_ path: String) -> Path {
        let currentPath = Path(path)
        if currentPath.isRelative {
            return self.path + currentPath
        } else {
            return currentPath
        }
    }

    public func validate() throws {

        if spec.configs.isEmpty {
            spec.configs = [Config(name: "Debug", type: .debug), Config(name: "Release", type: .release)]
        }

        var errors: [SpecValidationError.Error] = []

        func validateSettings(_ settings: Settings) -> [SpecValidationError.Error] {
            var errors: [SpecValidationError.Error] = []
            for preset in settings.presets {
                if let settings = spec.settingPresets[preset] {
                    errors += validateSettings(settings)
                } else {
                    errors.append(.invalidSettingsPreset(preset))
                }
            }
            return errors
        }

        for settings in spec.settingPresets.values {
            errors += validateSettings(settings)
        }

        for target in spec.targets {
            for dependency in target.dependencies {
                if case let .target(targetName) = dependency, spec.getTarget(targetName) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: targetName))
                }
            }

            for config in target.settings.configSettings.keys {
                if spec.getConfig(config) == nil {
                    errors.append(.invalidBuildSettingConfig(config))
                }
            }

            for source in target.sources {
                let sourcePath = getPath(source)
                if !sourcePath.exists {
                    errors.append(.missingTargetSource(target: target.name, source: sourcePath.string))
                }
            }

            for generatedScheme in target.generateSchemes {
                if !spec.configs.contains(where: { $0.name.contains(generatedScheme) && $0.type == .debug }) {
                    errors.append(.invalidTargetGeneratedSchema(target: target.name, scheme: generatedScheme, configType: .debug))
                }
                if !spec.configs.contains(where: { $0.name.contains(generatedScheme) && $0.type == .release }) {
                    errors.append(.invalidTargetGeneratedSchema(target: target.name, scheme: generatedScheme, configType: .release))
                }
            }

            errors += validateSettings(target.settings)
        }

        for scheme in spec.schemes {
            for buildTarget in scheme.build.targets {
                if spec.getTarget(buildTarget.target) == nil {
                    errors.append(.invalidSchemeTarget(scheme: scheme.name, target: buildTarget.target))
                }
            }
            if let buildAction = scheme.run, spec.getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.test, spec.getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.profile, spec.getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.analyze, spec.getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.archive, spec.getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
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

        let testAction = XCScheme.TestAction(buildConfiguration: scheme.test?.config ?? defaultDebugConfig.name, macroExpansion: buildableReference)

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
            for generatedScheme in target.generateSchemes {
                let schemeName = "\(target.name) \(generatedScheme)"

                let debugConfig = spec.configs.first { $0.type == .debug && $0.name.contains(generatedScheme) }!
                let releaseConfig = spec.configs.first { $0.type == .release && $0.name.contains(generatedScheme) }!

                let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfig: debugConfig.name, releaseConfig: releaseConfig.name)
                let scheme = try generateScheme(specScheme, pbxProject: pbxProject)
                xcschemes.append(scheme)
            }
        }

        return XCSharedData(schemes: xcschemes)
    }
}

public struct SpecValidationError: Error, CustomStringConvertible {

    public var errors: [Error]

    public enum Error: CustomStringConvertible {
        case invalidTargetDependency(target: String, dependency: String)
        case invalidSchemeTarget(scheme: String, target: String)
        case invalidSchemeConfig(scheme: String, config: String)
        case invalidBuildSettingConfig(String)
        case invalidSettingsPreset(String)
        case missingTargetSource(target: String, source: String)
        case invalidTargetGeneratedSchema(target: String, scheme: String, configType: ConfigType)

        public var description: String {
            switch self {
            case let .invalidTargetDependency(target, dependency): return "Target \(target.quoted) has invalid dependency: \(dependency.quoted)"
            case let .invalidSchemeTarget(scheme, target): return "Scheme \(scheme.quoted) has invalid build target \(target.quoted)"
            case let .invalidSchemeConfig(scheme, config): return "Scheme \(scheme.quoted) has invalid build configuration \(config.quoted)"
            case let .invalidBuildSettingConfig(config): return "Build setting has invalid build configuration \(config.quoted)"
            case let .missingTargetSource(target, source): return "Target \(target.quoted) has a missing source directory \(source.quoted)"
            case let .invalidSettingsPreset(preset): return "Invalid settings preset \(preset.quoted)"
            case let .invalidTargetGeneratedSchema(target, scheme, configType): return "Target \(target.quoted) has an invalid schema generation name which requires a config that has a \(configType.rawValue.quoted) type and contains the name \(scheme.quoted)"
            }
        }
    }

    public var description: String {
        let title: String
        if errors.count == 1 {
            title = "Spec validation error: "
        } else {
            title = "\(errors.count) Spec validations errors:\n\t- "
        }
        return "\(title)" + errors.map { $0.description }.joined(separator: "\n\t- ")
    }
}
