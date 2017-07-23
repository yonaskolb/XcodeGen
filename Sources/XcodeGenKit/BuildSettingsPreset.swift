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
        case let .config(config): return "configs/\(config.rawValue)"
        case let .platform(platform): return "platforms/\(platform.rawValue)"
        case let .product(product): return "products/\(product.rawValue)"
        case .base: return "base"
        }
    }

    private static var buildSettings: [String: BuildSettings] = [:]

    func getBuildSettings() throws -> BuildSettings? {
        if let group = BuildSettingsPreset.buildSettings[path] {
            return group
        }
        let settingsPath = Path(#file).parent().parent().parent() + "setting_groups/\(path).yml"
        guard settingsPath.exists else { return nil }
        let buildSettings = try BuildSettings(path: settingsPath)
        BuildSettingsPreset.buildSettings[path] = buildSettings
        return buildSettings
    }
}

extension BuildSettings: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        self.init(dictionary: jsonDictionary)
    }
}

