import Foundation
import JSONUtilities
import PathKit
import Version

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

            if settings.buildSettings.count == configs.count {
                var allConfigs = true
                for buildSetting in settings.buildSettings.keys {
                    var isConfig = false
                    for config in configs {
                        if config.name.lowercased().contains(buildSetting.lowercased()) {
                            isConfig = true
                        }
                    }
                    if !isConfig {
                        allConfigs = false
                    }
                }
                if allConfigs {
                    errors.append(.invalidPerConfigSettings)
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

        for (name, package) in packages {
            if case let .local(path) = package, !(basePath + Path(path).normalize()).exists {
                errors.append(.invalidLocalPackage(name))
            }
        }

        for (config, configFile) in configFiles {
            if !options.disabledValidations.contains(.missingConfigFiles) && !(basePath + configFile).exists {
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
                if !options.disabledValidations.contains(.missingConfigFiles) && !(basePath + configFile).exists {
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
                    if getTarget(testTarget.name) == nil {
                        errors.append(.invalidTargetSchemeTest(target: target.name, testTarget: testTarget.name))
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
                if getProjectTarget(dependency) == nil {
                    errors.append(.invalidTargetDependency(target: target.name, dependency: dependency))
                }
            }
        }

        for target in targets {
            for dependency in target.dependencies {
                switch dependency.type {
                case .target:
                    let dependencyTargetReference = try TargetReference(dependency.reference)

                    switch dependencyTargetReference.location {
                    case .local:
                        if getProjectTarget(dependency.reference) == nil {
                            errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                        }
                    case .project(let dependencyProjectName):
                        if getProjectReference(dependencyProjectName) == nil {
                            errors.append(.invalidTargetDependency(target: target.name, dependency: dependency.reference))
                        }
                    }
                case .sdk:
                    let path = Path(dependency.reference)
                    if !dependency.reference.contains("/") {
                        switch path.extension {
                        case "framework"?,
                             "tbd"?,
                             "dylib"?:
                            break
                        default:
                            errors.append(.invalidSDKDependency(target: target.name, dependency: dependency.reference))
                        }
                    }
                case .package:
                    if packages[dependency.reference] == nil {
                        errors.append(.invalidSwiftPackage(name: dependency.reference, target: target.name))
                    }
                default: break
                }
            }

            for source in target.sources {
                let sourcePath = basePath + source.path
                if !source.optional && !sourcePath.exists {
                    errors.append(.invalidTargetSource(target: target.name, source: sourcePath.string))
                }
            }
        }

        for projectReference in projectReferences {
            if !(basePath + projectReference.path).exists {
                errors.append(.invalidProjectReferencePath(projectReference))
            }
        }

        for scheme in schemes {
            errors.append(
                contentsOf: scheme.build.targets.compactMap { validationError(for: $0.target, in: scheme, action: "build") }
            )
            if let action = scheme.run, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            if let action = scheme.test, let config = action.config, getConfig(config) == nil {
                errors.append(.invalidSchemeConfig(scheme: scheme.name, config: config))
            }
            errors.append(
                contentsOf: scheme.test?.targets.compactMap { validationError(for: $0.targetReference, in: scheme, action: "test") } ?? []
            )
            errors.append(
                contentsOf: scheme.test?.coverageTargets.compactMap { validationError(for: $0, in: scheme, action: "test") } ?? []
            )
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

    public func validateMinimumXcodeGenVersion(_ xcodeGenVersion: Version) throws {
        if let minimumXcodeGenVersion = options.minimumXcodeGenVersion, xcodeGenVersion < minimumXcodeGenVersion {
            throw SpecValidationError(errors: [SpecValidationError.ValidationError.invalidXcodeGenVersion(minimumVersion: minimumXcodeGenVersion, version: xcodeGenVersion)])
        }
    }

    /// Returns a descriptive error if the given target reference was invalid otherwise `nil`.
    private func validationError(for targetReference: TargetReference, in scheme: Scheme, action: String) -> SpecValidationError.ValidationError? {
        switch targetReference.location {
        case .local where getProjectTarget(targetReference.name) == nil:
            return .invalidSchemeTarget(scheme: scheme.name, target: targetReference.name, action: action)
        case .project(let project) where getProjectReference(project) == nil:
            return .invalidProjectReference(scheme: scheme.name, reference: project)
        case .local, .project:
            return nil
        }
    }
}
