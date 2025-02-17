import Foundation

public enum SupportedDestination: String, CaseIterable {
    case iOS
    case tvOS
    case macOS
    case macCatalyst
    case watchOS
    case visionOS
}

extension SupportedDestination {
    
    public var string: String {
        switch self {
        case .iOS:
            return "ios"
        case .tvOS:
            return "tvos"
        case .macOS:
            return "macos"
        case .macCatalyst:
            return "maccatalyst"
        case .watchOS:
            return "watchos"
        case .visionOS:
            return "xros"
        }
    }
    
    // This is used to:
    // 1. Get the first one and apply SettingPresets 'Platforms' and 'Product_Platform' if the platform is 'auto'
    // 2. Sort, loop and merge together SettingPresets 'SupportedDestinations'
    public var priority: Int {
        switch self {
        case .iOS:
            return 0
        case .tvOS:
            return 1
        case .watchOS:
            return 2
        case .visionOS:
            return 3
        case .macOS:
            return 4
        case .macCatalyst:
            return 5
        }
    }
}
