//
//  BuildSettingGroupType.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 23/7/17.
//
//

import Foundation
import xcodeproj
import PathKit
import Yams
import JSONUtilities

enum BuildSettingsPreset {
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

    private static var buildSettings: [String: BuildSettings] = [:]

    func getBuildSettings() throws -> BuildSettings? {
        if let group = BuildSettingsPreset.buildSettings[path] {
            return group
        }
        let settingsPath = Path(#file).parent().parent().parent() + "SettingPresets/\(path).yml"
        guard settingsPath.exists,
        let buildSettings = try? BuildSettings(path: settingsPath) else { return nil }
        BuildSettingsPreset.buildSettings[path] = buildSettings
        return buildSettings
    }
}

extension BuildSettings: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        self.init(dictionary: jsonDictionary)
    }
}

