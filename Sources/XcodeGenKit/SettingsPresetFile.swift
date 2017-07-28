//
//  SettingsPresetFile.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 27/7/17.
//
//

import Foundation
import xcodeproj
import ProjectSpec

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
