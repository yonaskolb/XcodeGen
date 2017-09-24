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
    case configuration(ConfigurationType)
    case platform(Platform)
    case product(PBXProductType)
    case productPlatform(PBXProductType,Platform)
    case base

    var path: String {
        switch self {
        case let .configuration(configuration): return "Configurations/\(configuration.rawValue)"
        case let .platform(platform): return "Platforms/\(platform.rawValue)"
        case let .product(product): return "Products/\(product.name)"
        case let .productPlatform(product, platform): return "Product_Platform/\(product.name)_\(platform.rawValue)"
        case .base: return "base"
        }
    }

    var name: String {
        switch self {
        case let .configuration(configuration): return "\(configuration.rawValue) configuration"
        case let .platform(platform): return platform.rawValue
        case let .product(product): return product.name
        case let .productPlatform(product, platform): return "\(platform) \(product)"
        case .base: return "base"
        }
    }
}
