//
//  SpecValidation.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 24/9/17.
//

import Foundation
import ProjectSpec
import PathKit

extension ProjectSpec {

    public mutating func validate() throws {

        if configs.isEmpty {
            configs = [Config(name: "Debug", type: .debug), Config(name: "Release", type: .release)]
        }

        var errors: [SpecValidationError.Error] = []

        func validateSettings(_ settings: Settings) -> [SpecValidationError.Error] {
            var errors: [SpecValidationError.Error] = []
            for group in settings.groups {
                if let settings = settingGroups[group] {
                    errors += validateSettings(settings)
                } else {
                    errors.append(.invalidSettingsGroup(group))
                }
            }
            for config in settings.configSettings.keys {
                if getConfig(config) == nil {
                    errors.append(.invalidConfigReference(config))
                }
            }
            return errors
        }

        for fileGroup in fileGroups {
            if !(basePath + fileGroup).exists {
                errors.append(.invalidFileGroup(fileGroup))
            }
        }

        for (config, configFile) in configFiles {
            if !(basePath + configFile).exists {
                errors.append(.invalidConfigFile(configFile: configFile, config: config))
            }
        }

        for settings in settingGroups.values {
            errors += validateSettings(settings)
        }

        for target in targets {
            for dependency in target.dependencies {
                if dependency.type == .target, getTarget(dependency.reference) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                }
            }

            for (config, configFile) in target.configFiles {
                if !(basePath + configFile).exists {
                    errors.append(.invalidTargetConfigFile(configFile: configFile, config: config, target: target.name))
                }
            }

            for config in target.settings.configSettings.keys {
                if getConfig(config) == nil {
                    errors.append(.invalidBuildSettingConfig(config))
                }
            }

            for source in target.sources {
                let sourcePath = basePath + source
                if !sourcePath.exists {
                    errors.append(.missingTargetSource(target: target.name, source: sourcePath.string))
                }
            }

            if let scheme = target.scheme {

                for configVariant in scheme.configVariants {
                    if !configs.contains(where: { $0.name.contains(configVariant) && $0.type == .debug }) {
                        errors.append(.invalidTargetSchemeConfigVariant(target: target.name, configVariant: configVariant, configType: .debug))
                    }
                    if !configs.contains(where: { $0.name.contains(configVariant) && $0.type == .release }) {
                        errors.append(.invalidTargetSchemeConfigVariant(target: target.name, configVariant: configVariant, configType: .release))
                    }
                }

                for testTarget in scheme.testTargets {
                    if getTarget(testTarget) == nil {
                        errors.append(.invalidTargetSchemeTest(target: target.name, testTarget: testTarget))
                    }
                }
            }

            let scripts = target.prebuildScripts + target.postbuildScripts
            for script in scripts {
                if case let .path(pathString) = script.script {
                    let scriptPath = basePath + pathString
                    if !scriptPath.exists {
                        errors.append(.invalidBuildScriptPath(target: target.name, path: pathString))
                    }
                }
            }

            errors += validateSettings(target.settings)
        }

        for scheme in schemes {
            for buildTarget in scheme.build.targets {
                if getTarget(buildTarget.target) == nil {
                    errors.append(.invalidSchemeTarget(scheme: scheme.name, target: buildTarget.target))
                }
            }
            if let buildAction = scheme.run, getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.test, getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.profile, getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.analyze, getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
            if let buildAction = scheme.archive, getConfig(buildAction.config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: buildAction.config))
            }
        }

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }
}

public struct SpecValidationError: Error, CustomStringConvertible {

    public var errors: [Error]

    public enum Error: CustomStringConvertible {
        case invalidTargetDependency(target: String, dependency: String)
        case invalidSchemeTarget(scheme: String, target: String)
        case invalidSchemeConfig(scheme: String, config: String)
        case invalidConfigFile(configFile: String, config: String)
        case invalidTargetConfigFile(configFile: String, config: String, target: String)
        case invalidBuildSettingConfig(String)
        case invalidSettingsGroup(String)
        case missingTargetSource(target: String, source: String)
        case invalidBuildScriptPath(target: String, path: String)
        case invalidTargetSchemeConfigVariant(target: String, configVariant: String, configType: ConfigType)
        case invalidTargetSchemeTest(target: String, testTarget: String)
        case invalidFileGroup(String)
        case invalidConfigReference(String)

        public var description: String {
            switch self {
            case let .invalidTargetDependency(target, dependency): return "Target \(target.quoted) has invalid dependency: \(dependency.quoted)"
            case let .invalidTargetConfigFile(configFile, config, target): return "Target \(target.quoted) has invalid config file \(configFile.quoted) for config \(config.quoted)"
            case let .invalidConfigFile(configFile, config): return "Invalid config file \(configFile.quoted) for config \(config.quoted)"
            case let .invalidSchemeTarget(scheme, target): return "Scheme \(scheme.quoted) has invalid build target \(target.quoted)"
            case let .invalidSchemeConfig(scheme, config): return "Scheme \(scheme.quoted) has invalid build configuration \(config.quoted)"
            case let .invalidBuildSettingConfig(config): return "Build setting has invalid build configuration \(config.quoted)"
            case let .missingTargetSource(target, source): return "Target \(target.quoted) has a missing source directory \(source.quoted)"
            case let .invalidSettingsGroup(group): return "Invalid settings group \(group.quoted)"
            case let .invalidBuildScriptPath(target, path): return "Target \(target.quoted) has a script path that doesn't exist \(path.quoted)"
            case let .invalidTargetSchemeConfigVariant(target, configVariant, configType): return "Target \(target.quoted) has invalid scheme config varians which requires a config that has a \(configType.rawValue.quoted) type and contains the name \(configVariant.quoted)"
            case let .invalidTargetSchemeTest(target, test): return "Target \(target.quoted) scheme has invalid test \(test.quoted)"
            case let .invalidFileGroup(group): return "Invalid file group \(group.quoted)"
            case let .invalidConfigReference(config): return "Invalid config reference \(config.quoted)"
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
