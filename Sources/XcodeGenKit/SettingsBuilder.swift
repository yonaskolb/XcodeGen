import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeProj
import Yams

extension Project {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        // set project SDKROOT is a single platform
        if let firstPlatform = targets.first?.platform,
           targets.allSatisfy({ $0.platform == firstPlatform })
        {
            buildSettings["SDKROOT"] = firstPlatform.sdkRoot
        }

        if let type = config.type, options.settingPresets.applyProject {
            buildSettings += SettingsPresetFile.base.getBuildSettings()
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        // apply custom platform version
        for platform in Platform.allCases {
            if let version = options.deploymentTarget.version(for: platform) {
                buildSettings[platform.deploymentTargetSetting] = version.deploymentTarget
            }
        }

        // Prevent setting presets from overwriting settings in project xcconfig files
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
        
        if let specSupportedPlatforms = target.supportedPlatforms?.sorted(by: { $0.index < $1.index }),
           specSupportedPlatforms.count > 1 {
            
            var supportedPlatforms: [String] = []
            var targetedDeviceFamily: [String] = []
            
            for supportedPlatform in specSupportedPlatforms {
                let supportedPlatformBuildSettings = SettingsPresetFile.supportedPlatform(supportedPlatform).getBuildSettings()
                buildSettings += supportedPlatformBuildSettings
                
                if let value = supportedPlatformBuildSettings?["SUPPORTED_PLATFORMS"] as? String {
                    supportedPlatforms += value.components(separatedBy: " ")
                }
                if let value = supportedPlatformBuildSettings?["TARGETED_DEVICE_FAMILY"] as? String {
                    targetedDeviceFamily += value.components(separatedBy: ",")
                }
            }
            
            buildSettings["SUPPORTED_PLATFORMS"] = supportedPlatforms.joined(separator: " ")
            buildSettings["TARGETED_DEVICE_FAMILY"] = targetedDeviceFamily.joined(separator: ",")
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
            let isPartialMatch = config.name.lowercased().contains(configVariant.lowercased())
            if isPartialMatch {
                let exactConfig = getConfig(configVariant)
                let matchesExactlyToOtherConfig = exactConfig != nil && exactConfig?.name != config.name
                if !matchesExactlyToOtherConfig {
                    buildSettings += getBuildSettings(settings: settings, config: config)
                }
            }
        }

        return buildSettings
    }

    // combines all levels of a target's settings: target, target config, project, project config
    public func getCombinedBuildSetting(_ setting: String, target: ProjectTarget, config: Config) -> Any? {
        if let target = target as? Target,
            let value = getTargetBuildSettings(target: target, config: config)[setting] {
            return value
        }
        if let configFilePath = target.configFiles[config.name],
            let value = loadConfigFileBuildSettings(path: configFilePath)?[setting] {
            return value
        }
        if let value = getProjectBuildSettings(config: config)[setting] {
            return value
        }
        if let configFilePath = configFiles[config.name],
            let value = loadConfigFileBuildSettings(path: configFilePath)?[setting] {
            return value
        }
        return nil
    }

    public func getBoolBuildSetting(_ setting: String, target: ProjectTarget, config: Config) -> Bool? {
        guard let value = getCombinedBuildSetting(setting, target: target, config: config) else { return nil }

        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            return stringValue == "YES"
        }

        return nil
    }

    public func targetHasBuildSetting(_ setting: String, target: Target, config: Config) -> Bool {
        getCombinedBuildSetting(setting, target: target, config: config) != nil
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
        if let cached = configFileSettings[configFilePath.string] {
            return cached.value
        } else {
            guard let configFile = try? XCConfig(path: configFilePath) else {
                configFileSettings[configFilePath.string] = .nothing
                return nil
            }
            let settings = configFile.flattenedBuildSettings()
            configFileSettings[configFilePath.string] = .cached(settings)
            return settings
        }
    }
}

private enum Cached<T> {
    case cached(T)
    case nothing

    var value: T? {
        switch self {
        case let .cached(value): return value
        case .nothing: return nil
        }
    }
}

// cached flattened xcconfig file settings
private var configFileSettings: [String: Cached<BuildSettings>] = [:]

// cached setting preset settings
private var settingPresetSettings: [String: Cached<BuildSettings>] = [:]

extension SettingsPresetFile {

    public func getBuildSettings() -> BuildSettings? {
        if let cached = settingPresetSettings[path] {
            return cached.value
        }
        let bundlePath = Path(Bundle.main.bundlePath)
        let relativePath = Path("SettingPresets/\(path).yml")
        var possibleSettingsPaths: [Path] = [
            relativePath,
            bundlePath + relativePath,
            bundlePath + "../share/xcodegen/\(relativePath)",
            Path(#file).parent().parent().parent() + relativePath,
        ]

        if let resourcePath = Bundle.main.resourcePath {
            possibleSettingsPaths.append(Path(resourcePath) + relativePath)
        }

        if let symlink = try? (bundlePath + "xcodegen").symlinkDestination() {
            possibleSettingsPaths = [
                symlink.parent() + relativePath,
            ] + possibleSettingsPaths
        }

        guard let settingsPath = possibleSettingsPaths.first(where: { $0.exists }) else {
            switch self {
            case .base, .config, .platform, .supportedPlatform:
                print("No \"\(name)\" settings found")
            case .product, .productPlatform:
                break
            }
            settingPresetSettings[path] = .nothing
            return nil
        }

        guard let buildSettings = try? loadYamlDictionary(path: settingsPath) else {
            print("Error parsing \"\(name)\" settings")
            return nil
        }
        settingPresetSettings[path] = .cached(buildSettings)
        return buildSettings
    }
}
