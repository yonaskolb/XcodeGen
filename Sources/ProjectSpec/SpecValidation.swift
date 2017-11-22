import Foundation
import PathKit

extension ProjectSpec {

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
                    errors.append(.invalidBuildSettingConfig(config))
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
            if getConfig(config) == nil {
                errors.append(.invalidConfigFileConfig(config))
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
                    errors.append(.invalidTargetConfigFile(target: target.name, configFile: configFile, config: config))
                }
                if getConfig(config) == nil {
                    errors.append(.invalidConfigFileConfig(config))
                }
            }

            for source in target.sources {
                let sourcePath = basePath + source.path
                if !sourcePath.exists {
                    errors.append(.invalidTargetSource(target: target.name, source: sourcePath.string))
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

                if scheme.configVariants.isEmpty {
                    if !configs.contains(where: { $0.type == .debug }) {
                        errors.append(.missingConfigTypeForGeneratedTargetScheme(target: target.name, configType: .debug))
                    }
                    if !configs.contains(where: { $0.type == .release }) {
                        errors.append(.missingConfigTypeForGeneratedTargetScheme(target: target.name, configType: .release))
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
                        errors.append(.invalidBuildScriptPath(target: target.name, name: script.name, path: pathString))
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
