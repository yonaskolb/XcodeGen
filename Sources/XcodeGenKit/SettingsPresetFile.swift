import Foundation
import ProjectSpec
import XcodeProj

public enum SettingsPresetFile {
    case config(ConfigType)
    case platform(Platform)
    case product(PBXProductType)
    case productPlatform(PBXProductType, Platform)
    case base

    var path: String {
        switch self {
        case let .config(config): return "Configs/\(config.rawValue)"
        case let .platform(platform): return "Platforms/\(platform.rawValue)"
        case let .product(product): return "Products/\(product.name)"
        case let .productPlatform(product, platform): return "Product_Platform/\(product.name)_\(platform.rawValue)"
        case .base: return "base"
        }
    }

    var name: String {
        switch self {
        case let .config(config): return "\(config.rawValue) config"
        case let .platform(platform): return platform.rawValue
        case let .product(product): return product.name
        case let .productPlatform(product, platform): return "\(platform) \(product)"
        case .base: return "base"
        }
    }
}
