//
//  SettingPreset.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 26/7/17.
//
//

import Foundation
import JSONUtilities
import xcodeproj

public struct SettingPreset: Equatable, CustomStringConvertible {
    public var settings: Settings
    public var settingPresets: [String]

    public init(settings: Settings, settingPresets: [String] = []) {
        self.settings = settings
        self.settingPresets = settingPresets
    }

    public static func ==(lhs: SettingPreset, rhs: SettingPreset) -> Bool {
        return lhs.settings == rhs.settings && lhs.settingPresets == rhs.settingPresets
    }

    public var description: String {
        return "\(settings)\nPresets: \(settingPresets)"
    }
}

public enum SettingsPresetFile {
    case config(ConfigType)
    case platform(Platform)
    case product(PBXProductType)
    case base

    var path: String {
        switch self {
        case let .config(config): return "Configs/\(config.rawValue)"
        case let .platform(platform): return "Platforms/\(platform.rawValue)"
        case let .product(product): return "Products/\(product.rawValue)"
        case .base: return "base"
        }
    }
}

extension SettingPreset: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["settings"] == nil {
            settings = try Settings(jsonDictionary: jsonDictionary)
            settingPresets = []
        } else {
            settings = try jsonDictionary.json(atKeyPath: "settings")
            settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? []
        }
    }
}
