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
import JSONUtilities
import Yams
import ProjectSpec

public class ProjectGenerator {

    var spec: ProjectSpec
    var path: Path
    let currentXcodeVersion = "0900"

    public init(spec: ProjectSpec, path: Path) {
        self.spec = spec
        self.path = path
    }

    var defaultDebugConfiguration: Configuration {
        return spec.configurations.first { $0.type == .debug }!
    }

    var defaultReleaseConfiguration: Configuration {
        return spec.configurations.first { $0.type == .release }!
    }

    public func validate() throws {

        if spec.configurations.isEmpty {
            spec.configurations = [Configuration(name: "Debug", type: .debug), Configuration(name: "Release", type: .release)]
        }

        var errors: [SpecValidationError.Error] = []

        func validateSettings(_ settings: Settings) -> [SpecValidationError.Error] {
            var errors: [SpecValidationError.Error] = []
            for preset in settings.groups {
                if let settings = spec.settingGroups[preset] {
                    errors += validateSettings(settings)
                } else {
                    errors.append(.invalidSettingsPreset(preset))
                }
            }
            return errors
        }

        for settings in spec.settingGroups.values {
            errors += validateSettings(settings)
        }

        for target in spec.targets {
            for dependency in target.dependencies {
                if dependency.type == .target, spec.getTarget(dependency.reference) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                }
            }

            for (configuration, configurationFile) in target.configurationFiles {
                if !(path + configurationFile).exists {
                    errors.append(.invalidTargetConfigurationFile(configurationFile: configurationFile, configuration: configuration, target: target.name))
                }
            }

            for configuration in target.settings.configurationSettings.keys {
                if spec.getConfiguration(configuration) == nil {
                    errors.append(.invalidBuildSettingConfiguration(configuration))
                }
            }

            for source in target.sources {
                let sourcePath = path + source
                if !sourcePath.exists {
                    errors.append(.missingTargetSource(target: target.name, source: sourcePath.string))
                }
            }

            if let scheme = target.scheme {

                for configurationVariant in scheme.configurationVariants {
                    if !spec.configurations.contains(where: { $0.name.contains(configurationVariant) && $0.type == .debug }) {
                        errors.append(.invalidTargetSchemeConfigurationVariant(target: target.name, configurationVariant: configurationVariant, configurationType: .debug))
                    }
                    if !spec.configurations.contains(where: { $0.name.contains(configurationVariant) && $0.type == .release }) {
                        errors.append(.invalidTargetSchemeConfigurationVariant(target: target.name, configurationVariant: configurationVariant, configurationType: .release))
                    }
                }

                for testTarget in scheme.testTargets {
                    if spec.getTarget(testTarget) == nil {
                        errors.append(.invalidTargetSchemeTest(target: target.name, testTarget: testTarget))
                    }
                }
            }

            let scripts = target.prebuildScripts + target.postbuildScripts
            for script in scripts {
                if case let .path(pathString) = script.script {
                    let scriptPath = path + pathString
                    if !scriptPath.exists {
                        errors.append(.invalidBuildScriptPath(target: target.name, path: pathString))
                    }
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
            if let buildAction = scheme.run, spec.getConfiguration(buildAction.configuration) == nil {
                errors.append(.invalidSchemeConfiguration(scheme: scheme.name, configuration: buildAction.configuration))
            }
            if let buildAction = scheme.test, spec.getConfiguration(buildAction.configuration) == nil {
                errors.append(.invalidSchemeConfiguration(scheme: scheme.name, configuration: buildAction.configuration))
            }
            if let buildAction = scheme.profile, spec.getConfiguration(buildAction.configuration) == nil {
                errors.append(.invalidSchemeConfiguration(scheme: scheme.name, configuration: buildAction.configuration))
            }
            if let buildAction = scheme.analyze, spec.getConfiguration(buildAction.configuration) == nil {
                errors.append(.invalidSchemeConfiguration(scheme: scheme.name, configuration: buildAction.configuration))
            }
            if let buildAction = scheme.archive, spec.getConfiguration(buildAction.configuration) == nil {
                errors.append(.invalidSchemeConfiguration(scheme: scheme.name, configuration: buildAction.configuration))
            }
        }

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }

    public func generateProject() throws -> XcodeProj {
        try validate()
        let pbxProjGenerator = PBXProjGenerator(spec: spec, path: path, currentXcodeVersion: currentXcodeVersion)
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

            let targetReference = pbxProject.nativeTargets.first { $0.name == buildTarget.target }!

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

        let testAction = XCScheme.TestAction(buildConfiguration: scheme.test?.configuration ?? defaultDebugConfiguration.name,
                                             macroExpansion: buildableReference,
                                             testables: testables)

        let launchAction = XCScheme.LaunchAction(buildableProductRunnable: productRunable,
                                                 buildConfiguration: scheme.run?.configuration ?? defaultDebugConfiguration.name)

        let profileAction = XCScheme.ProfileAction(buildableProductRunnable: productRunable,
                                                   buildConfiguration: scheme.profile?.configuration ?? defaultReleaseConfiguration.name)

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: scheme.analyze?.configuration ?? defaultDebugConfiguration.name)

        let archiveAction = XCScheme.ArchiveAction(buildConfiguration: scheme.archive?.configuration ?? defaultReleaseConfiguration.name, revealArchiveInOrganizer: true)

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
            if let scheme = target.scheme {

                if scheme.configurationVariants.isEmpty {
                    let schemeName = target.name

                    let debugConfiguration = spec.configurations.first { $0.type == .debug }!
                    let releaseConfiguration = spec.configurations.first { $0.type == .release }!

                    let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfiguration: debugConfiguration.name, releaseConfiguration: releaseConfiguration.name)
                    let scheme = try generateScheme(specScheme, pbxProject: pbxProject, tests: scheme.testTargets)
                    xcschemes.append(scheme)
                } else {
                    for configurationVariant in scheme.configurationVariants {

                        let schemeName = "\(target.name) \(configurationVariant)"

                        let debugConfiguration = spec.configurations.first { $0.type == .debug && $0.name.contains(configurationVariant) }!
                        let releaseConfiguration = spec.configurations.first { $0.type == .release && $0.name.contains(configurationVariant) }!

                        let specScheme = Scheme(name: schemeName, targets: [Scheme.BuildTarget(target: target.name)], debugConfiguration: debugConfiguration.name, releaseConfiguration: releaseConfiguration.name)
                        let scheme = try generateScheme(specScheme, pbxProject: pbxProject, tests: scheme.testTargets)
                        xcschemes.append(scheme)
                    }
                }
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
        case invalidSchemeConfiguration(scheme: String, configuration: String)
        case invalidTargetConfigurationFile(configurationFile: String, configuration: String, target: String)
        case invalidBuildSettingConfiguration(String)
        case invalidSettingsPreset(String)
        case missingTargetSource(target: String, source: String)
        case invalidBuildScriptPath(target: String, path: String)
        case invalidTargetSchemeConfigurationVariant(target: String, configurationVariant: String, configurationType: ConfigurationType)
        case invalidTargetSchemeTest(target: String, testTarget: String)

        public var description: String {
            switch self {
            case let .invalidTargetDependency(target, dependency): return "Target \(target.quoted) has invalid dependency: \(dependency.quoted)"
            case let .invalidTargetConfigurationFile(configurationFile, configuration, target): return "Target \(target.quoted) has invalid configuration file \(configurationFile.quoted) for configuration \(configuration.quoted)"
            case let .invalidSchemeTarget(scheme, target): return "Scheme \(scheme.quoted) has invalid build target \(target.quoted)"
            case let .invalidSchemeConfiguration(scheme, configuration): return "Scheme \(scheme.quoted) has invalid build configuration \(configuration.quoted)"
            case let .invalidBuildSettingConfiguration(configuration): return "Build setting has invalid build configuration \(configuration.quoted)"
            case let .missingTargetSource(target, source): return "Target \(target.quoted) has a missing source directory \(source.quoted)"
            case let .invalidSettingsPreset(preset): return "Invalid settings preset \(preset.quoted)"
            case let .invalidBuildScriptPath(target, path): return "Target \(target.quoted) has a script path that doesn't exist \(path.quoted)"
            case let .invalidTargetSchemeConfigurationVariant(target, configurationVariant, configurationType): return "Target \(target.quoted) has invalid scheme configuration varians which requires a configuration that has a \(configurationType.rawValue.quoted) type and contains the name \(configurationVariant.quoted)"
            case let .invalidTargetSchemeTest(target, test): return "Target \(target.quoted) scheme has invalid test \(test.quoted)"
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
