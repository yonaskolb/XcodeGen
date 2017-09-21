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

    public func getProjectBuildSettings(configuration: Configuration) -> BuildSettings {

        var buildSettings: BuildSettings = [:]
        buildSettings += SettingsPresetFile.base.getBuildSettings()

        if let type = configuration.type {
            buildSettings += SettingsPresetFile.configuration(type).getBuildSettings()
        }

        buildSettings += getBuildSettings(settings: settings, configuration: configuration)

        return buildSettings
    }

    public func getTargetBuildSettings(target: Target, configuration: Configuration) -> BuildSettings {
        var buildSettings = BuildSettings()

        buildSettings += SettingsPresetFile.platform(target.platform).getBuildSettings()
        buildSettings += SettingsPresetFile.product(target.type).getBuildSettings()
        buildSettings += SettingsPresetFile.productPlatform(target.type, target.platform).getBuildSettings()
        buildSettings += getBuildSettings(settings: target.settings, configuration: configuration)

        return buildSettings
    }

    public func getBuildSettings(settings: Settings, configuration: Configuration) -> BuildSettings {
        var buildSettings: BuildSettings = [:]

        for preset in settings.groups {
            let presetSettings = settingGroups[preset]!
            buildSettings += getBuildSettings(settings: presetSettings, configuration: configuration)
        }

        buildSettings += settings.buildSettings

        if let configurationSettings = settings.configurationSettings[configuration.name] {
            buildSettings += getBuildSettings(settings: configurationSettings, configuration: configuration)
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
            case .base, .configuration, .platform:
                print("No \"\(name)\" settings found at \(settingsPath)")
            case .product, .productPlatform:
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
