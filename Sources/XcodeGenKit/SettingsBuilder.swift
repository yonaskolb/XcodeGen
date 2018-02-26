import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcproj
import Yams

extension ProjectSpec {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        if let type = config.type, options.settingPresets.applyProject {
            buildSettings += SettingsPresetFile.base.getBuildSettings()
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        // apply custom platform version
        for platform in Platform.all {
            if let version = options.deploymentTarget.version(for: platform) {
                buildSettings[platform.deploymentTargetSetting] = version.deploymentTarget
            }
        }

        // Prevent setting presets from overrwriting settings in project xcconfig files
        if let configPath = configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }

        buildSettings += getBuildSettings(settings: settings, config: config)

        return buildSettings
    }

    public func getTargetBuildSettings(target: Target, config: Config) -> BuildSettings {
        var buildSettings = BuildSettings()

        if options.settingPresets.applyTarget {
            buildSettings += SettingsPresetFile.platform(target.platform).getBuildSettings()
            buildSettings += SettingsPresetFile.product(target.type).getBuildSettings()
            buildSettings += SettingsPresetFile.productPlatform(target.type, target.platform).getBuildSettings()
        }

        // apply custom platform version
        if let version = target.deploymentTarget {
            buildSettings[target.platform.deploymentTargetSetting] = version.deploymentTarget
        }

        // Prevent setting presets from overrwriting settings in target xcconfig files
        if let configPath = target.configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }
        // Prevent setting presets from overrwriting settings in project xcconfig files
        if let configPath = configFiles[config.name] {
            buildSettings = removeConfigFileSettings(from: buildSettings, configPath: configPath)
        }

        buildSettings += getBuildSettings(settings: target.settings, config: config)

        return buildSettings
    }

    public func getBuildSettings(settings: Settings, config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        for group in settings.groups {
            if let settings = settingGroups[group] {
                buildSettings += getBuildSettings(settings: settings, config: config)
            }
        }

        buildSettings += settings.buildSettings

        for (configVariant, settings) in settings.configSettings {
            if config.name.lowercased().contains(configVariant.lowercased()) {
                buildSettings += getBuildSettings(settings: settings, config: config)
            }
        }

        return buildSettings
    }

    // combines all levels of a target's settings: target, target config, project, project config
    public func getCombinedBuildSettings(basePath: Path, target: Target, config: Config, includeProject: Bool = true) -> BuildSettings {
        var buildSettings: BuildSettings = [:]
        if includeProject {
            if let configFilePath = configFiles[config.name] {
                buildSettings += loadConfigFileBuildSettings(path: configFilePath)
            }
            buildSettings += getProjectBuildSettings(config: config)
        }
        if let configFilePath = target.configFiles[config.name] {
            buildSettings += loadConfigFileBuildSettings(path: configFilePath)
        }
        buildSettings += getTargetBuildSettings(target: target, config: config)
        return buildSettings
    }

    public func targetHasBuildSetting(_ setting: String, basePath: Path, target: Target, config: Config, includeProject: Bool = true) -> Bool {
        let buildSettings = getCombinedBuildSettings(
            basePath: basePath,
            target: target,
            config: config,
            includeProject: includeProject
        )
        return buildSettings[setting] != nil
    }

    /// Removes values from build settings if they are defined in an xcconfig file
    private func removeConfigFileSettings(from buildSettings: BuildSettings, configPath: String) -> BuildSettings {
        var buildSettings = buildSettings

        if let configSettings = loadConfigFileBuildSettings(path: configPath) {
            for key in configSettings.keys {
                // FIXME: Catch platform specifier. e.g. LD_RUNPATH_SEARCH_PATHS[sdk=iphone*]
                buildSettings.removeValue(forKey: key)
                buildSettings.removeValue(forKey: key.quoted)
            }
        }

        return buildSettings
    }

    /// Returns cached build settings from a config file
    private func loadConfigFileBuildSettings(path: String) -> BuildSettings? {
        let configFilePath = basePath + path
        if let settings = configFileSettings[configFilePath.string] {
            return settings
        } else {
            guard let configFile = try? XCConfig(path: configFilePath) else { return nil }
            let settings = configFile.flattenedBuildSettings()
            configFileSettings[configFilePath.string] = settings
            return settings
        }
    }
}

// cached flattened xcconfig file settings
private var configFileSettings: [String: BuildSettings] = [:]

// cached setting preset settings
private var settingPresetSettings: [String: BuildSettings] = [:]

extension SettingsPresetFile {

    public func getBuildSettings() -> BuildSettings? {
        if let group = settingPresetSettings[path] {
            return group
        }
        let bundlePath = Path(Bundle.main.bundlePath)
        let relativePath = Path("SettingPresets/\(path).yml")
        var possibleSettingsPaths: [Path] = [
            relativePath,
            bundlePath + relativePath,
            bundlePath + "../share/xcodegen/\(relativePath)",
            Path(#file).parent().parent().parent() + relativePath,
        ]

        if let symlink = try? bundlePath.symlinkDestination() {
            possibleSettingsPaths = [
                symlink + relativePath,
            ] + possibleSettingsPaths
        }

        guard let settingsPath = possibleSettingsPaths.first(where: { $0.exists }) else {
            switch self {
            case .base, .config, .platform:
                print("No \"\(name)\" settings found")
            case .product, .productPlatform:
                break
            }
            return nil
        }

        guard let buildSettings = try? loadYamlDictionary(path: settingsPath) else {
            print("Error parsing \"\(name)\" settings")
            return nil
        }
        settingPresetSettings[path] = buildSettings
        return buildSettings
    }
}
