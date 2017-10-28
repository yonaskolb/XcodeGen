//
//  SettingsBuilder.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 26/7/17.
//
//

import Foundation
import xcproj
import PathKit
import ProjectSpec
import Yams
import JSONUtilities

extension ProjectSpec {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        if let type = config.type, options.settingPresets.applyProject {
            buildSettings += SettingsPresetFile.base.getBuildSettings()
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        if let configPath = configFiles[config.name] {
            // Do not overwrite project xcconfig's value.
            if let configFile = try? XCConfig(path: basePath + configPath) {
                removeValues(for: configFile.flattenedBuildSettings().keys, buildSettings: &buildSettings)
            }
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

        // Do not overwrite target xcconfig's values.
        if let configPath = target.configFiles[config.name] {
            if let configFile = try? XCConfig(path: basePath + configPath) {
                removeValues(for: configFile.flattenedBuildSettings().keys, buildSettings: &buildSettings)
            }
        }
        // Avoid overwriting target xcconfig's values by base presets' values.
        if let configPath = configFiles[config.name] {
            if let configFile = try? XCConfig(path: basePath + configPath) {
                removeValues(for: configFile.flattenedBuildSettings().keys, buildSettings: &buildSettings)
            }
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
                if let configFile = try? XCConfig(path: basePath + configFilePath) {
                    buildSettings += configFile.flattenedBuildSettings()
                }
            }
            buildSettings += getProjectBuildSettings(config: config)
        }
        if let configFilePath = target.configFiles[config.name] {
            if let configFile = try? XCConfig(path: basePath + configFilePath) {
                buildSettings += configFile.flattenedBuildSettings()
            }
        }
        buildSettings += getTargetBuildSettings(target: target, config: config)
        return buildSettings
    }

    public func targetHasBuildSetting(_ setting: String, basePath: Path, target: Target, config: Config, includeProject: Bool = true) -> Bool {
        let buildSettings = getCombinedBuildSettings(basePath: basePath, target: target, config: config, includeProject: includeProject)
        return buildSettings[setting] != nil
    }

    // MARK: private

    /// Removes values for specified keys in buildSettings
    /// - parameter keys: Keys for values to remove
    /// - paramerter buildSettings: inout dictionary
    private func removeValues(for keys: BuildSettings.Keys, buildSettings: inout BuildSettings) {
        for k in keys {
            // FIXME: Catch platform specifier. e.g. LD_RUNPATH_SEARCH_PATHS[sdk=iphone*]
            buildSettings.removeValue(forKey: k)
            buildSettings.removeValue(forKey: "\"\(k)\"")
        }
    }
}

private var buildSettingFiles: [String: BuildSettings] = [:]

extension SettingsPresetFile {

    public func getBuildSettings() -> BuildSettings? {
        if let group = buildSettingFiles[path] {
            return group
        }
        let relativePath = "SettingPresets/\(path).yml"
        let possibleSettingsPaths: [Path] = [
            Path(relativePath),
            Path(Bundle.main.bundlePath) + relativePath,
            Path(Bundle.main.bundlePath) + "../share/xcodegen/\(relativePath)",
            Path(#file).parent().parent().parent() + relativePath,
        ]

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
        buildSettingFiles[path] = buildSettings
        return buildSettings
    }
}
