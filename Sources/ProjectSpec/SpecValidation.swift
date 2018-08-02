import Foundation
import PathKit

extension Project {

    public func validate() throws {

        var errors: [SpecValidationError.ValidationError] = []
        func validateSettings(_ settings: Settings) -> [SpecValidationError.ValidationError] {
            var errors: [SpecValidationError.ValidationError] = []
            for group in settings.groups {
                if let settings = settingGroups[group] {
                    errors += validateSettings(settings)
                } else {
                    errors.append(.invalidSettingsGroup(group))
                }
            }
            for config in settings.configSettings.keys {
                if !configs.contains(where: { $0.name.lowercased().contains(config.lowercased()) }) {
                    if !options.disabledValidations.contains(.missingConfigs) {
                        errors.append(.invalidBuildSettingConfig(config))
                    }
                }
            }
            return errors
        }

        errors += validateSettings(settings)

        for fileGroup in fileGroups {
            if !(basePath + fileGroup).exists {
                errors.append(.invalidFileGroup(fileGroup))
            }
        }

        for (config, configFile) in configFiles {
            if !(basePath + configFile).exists {
                errors.append(.invalidConfigFile(configFile: configFile, config: config))
            }
            if !options.disabledValidations.contains(.missingConfigs) && getConfig(config) == nil {
                errors.append(.invalidConfigFileConfig(config))
            }
        }

        if let configName = options.defaultConfig {
            if !configs.contains(where: { $0.name == configName }) {
                errors.append(.missingDefaultConfig(configName: configName))
            }
        }

        for settings in settingGroups.values {
            errors += validateSettings(settings)
        }

        for target in projectTargets {

            for (config, configFile) in target.configFiles {
                if !(basePath + configFile).exists {
                    errors.append(.invalidTargetConfigFile(target: target.name, configFile: configFile, config: config))
                }
                if !options.disabledValidations.contains(.missingConfigs) && getConfig(config) == nil {
                    errors.append(.invalidConfigFileConfig(config))
                }
            }

            if let scheme = target.scheme {

                for configVariant in scheme.configVariants {
                    if !configs.contains(where: { $0.name.contains(configVariant) && $0.type == .debug }) {
                        errors.append(.invalidTargetSchemeConfigVariant(
                            target: target.name,
                            configVariant: configVariant,
                            configType: .debug
                        ))
                    }
                    if !configs.contains(where: { $0.name.contains(configVariant) && $0.type == .release }) {
                        errors.append(.invalidTargetSchemeConfigVariant(
                            target: target.name,
                            configVariant: configVariant,
                            configType: .release
                        ))
                    }
                }

                if scheme.configVariants.isEmpty {
                    if !configs.contains(where: { $0.type == .debug }) {
                        errors.append(.missingConfigForTargetScheme(target: target.name, configType: .debug))
                    }
                    if !configs.contains(where: { $0.type == .release }) {
                        errors.append(.missingConfigForTargetScheme(target: target.name, configType: .release))
                    }
                }

                for testTarget in scheme.testTargets {
                    if getTarget(testTarget) == nil {
                        errors.append(.invalidTargetSchemeTest(target: target.name, testTarget: testTarget))
                    }
                }
            }

            for script in target.buildScripts {
                if case let .path(pathString) = script.script {
                    let scriptPath = basePath + pathString
                    if !scriptPath.exists {
                        errors.append(.invalidBuildScriptPath(target: target.name, name: script.name, path: pathString))
                    }
                }
            }

            errors += validateSettings(target.settings)
        }

        for target in aggregateTargets {
            for dependency in target.targets {
                if getTarget(dependency) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency))
                }
            }
        }

        for target in targets {
            for dependency in target.dependencies {
                if dependency.type == .target, getTarget(dependency.reference) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                }
            }

            for source in target.sources {
                let sourcePath = basePath + source.path
                if !source.optional && !sourcePath.exists {
                    errors.append(.invalidTargetSource(target: target.name, source: sourcePath.string))
                }
            }
        }

        for scheme in schemes {
            for buildTarget in scheme.build.targets {
                if getTarget(buildTarget.target) == nil {
                    errors.append(.invalidSchemeTarget(scheme: scheme.name, target: buildTarget.target))
                }
            }
            if let action = scheme.run, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.test, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.profile, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.analyze, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.archive, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
        }

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }
}
