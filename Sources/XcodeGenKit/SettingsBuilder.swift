//
//  SettingsBuilder.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 26/7/17.
//
//

import Foundation
import xcodeproj
import PathKit

extension Spec {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {

        var buildSettings: BuildSettings = .empty
        buildSettings += SettingsPresetFile.base.getBuildSettings()

        if let type = config.type {
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        for preset in config.settingPresets {
            buildSettings += getBuildSettings(preset: preset, config: config)
        }

        buildSettings += config.settings

        return buildSettings
    }

    public func getTargetBuildSettings(target: Target, config: Config) -> BuildSettings {
        var buildSettings = BuildSettings()

        buildSettings += SettingsPresetFile.platform(target.platform).getBuildSettings()
        buildSettings += SettingsPresetFile.product(target.type).getBuildSettings()

        for preset in target.settingPresets {
            buildSettings += getBuildSettings(preset: preset, config: config)
        }

        buildSettings += getBuildSettings(settings: target.settings, config: config)

        return buildSettings
    }

    public func getBuildSettings(preset: String, config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = .empty
        let settingPreset = settingPresets[preset]!

        for preset in settingPreset.settingPresets {
            buildSettings += getBuildSettings(preset: preset, config: config)
        }

        buildSettings += getBuildSettings(settings: settingPreset.settings, config: config)

        return buildSettings
    }

    public func getBuildSettings(settings: Settings, config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = .empty

        buildSettings += settings.buildSettings
        buildSettings += settings.configSettings[config.name]

        return buildSettings
    }
}


private var buildSettingFiles: [String: BuildSettings] = [:]

extension SettingsPresetFile {

    public func getBuildSettings() -> BuildSettings? {
        if let group = buildSettingFiles[path] {
            return group
        }
        let settingsPath = Path(#file).parent().parent().parent() + "SettingPresets/\(path).yml"
        guard settingsPath.exists,
            let buildSettings = try? BuildSettings(path: settingsPath) else { return nil }
        buildSettingFiles[path] = buildSettings
        return buildSettings
    }
}
