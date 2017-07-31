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
import ProjectSpec

extension ProjectSpec {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {

        var buildSettings: BuildSettings = .empty
        buildSettings += SettingsPresetFile.base.getBuildSettings()

        if let type = config.type {
            buildSettings += SettingsPresetFile.config(type).getBuildSettings()
        }

        buildSettings += getBuildSettings(settings: settings, config: config)

        return buildSettings
    }

    public func getTargetBuildSettings(target: Target, config: Config) -> BuildSettings {
        var buildSettings = BuildSettings()

        buildSettings += SettingsPresetFile.platform(target.platform).getBuildSettings()
        buildSettings += SettingsPresetFile.product(target.type).getBuildSettings()
        buildSettings += getBuildSettings(settings: target.settings, config: config)

        return buildSettings
    }

    public func getBuildSettings(settings: Settings, config: Config) -> BuildSettings {
        var buildSettings: BuildSettings = .empty

        for preset in settings.presets {
            let presetSettings = settingPresets[preset]!
            buildSettings += getBuildSettings(settings: presetSettings, config: config)
        }

        buildSettings += settings.buildSettings

        if let configSettings = settings.configSettings[config.name] {
            buildSettings += getBuildSettings(settings: configSettings, config: config)
        }

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
