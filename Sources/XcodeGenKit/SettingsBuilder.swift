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
import Yams
import JSONUtilities

extension ProjectSpec {

    public func getProjectBuildSettings(config: Config) -> BuildSettings {

        var buildSettings: BuildSettings = [:]
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
        var buildSettings: BuildSettings = [:]

        for preset in settings.groups {
            let presetSettings = settingGroups[preset]!
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
        let relativePath = "SettingPresets/\(path).yml"
        var settingsPath = Path(Bundle.main.bundlePath) + "../share/xcodegen/\(relativePath)"

        if !settingsPath.exists {
            // maybe running locally
            settingsPath = Path(#file).parent().parent().parent() + relativePath
        }
        guard settingsPath.exists else {
            switch self {
            case .base, .config, .platform:
                print("No \"\(name)\" settings found at \(settingsPath)")
            case .product:
                break
            }
            return nil
        }

        guard let buildSettings = try? loadSettings(path: settingsPath) else {
            print("Error parsing \"\(name)\" settings")
            return nil
        }
        buildSettingFiles[path] = buildSettings
        return buildSettings
    }

    public func loadSettings(path: Path) throws -> BuildSettings {
        let content: String = try path.read()
        if content == "" {
            return [:]
        }
        let yaml = try Yams.load(yaml: content)
        guard let dictionary = yaml as? JSONDictionary else {
            throw JSONUtilsError.fileNotAJSONDictionary
        }
        return dictionary
    }
}
