import Foundation

public enum SupportedPlatforms: String, CaseIterable {
    case iOS
    case tvOS
    case macOS
    case macCatalyst
}

public extension SupportedPlatforms {
    
    var string: String {
        switch self {
        case .iOS:
            return "ios"
        case .tvOS:
            return "tvos"
        case .macOS:
            return "macos"
        case .macCatalyst:
            return "maccatalyst"
        }
    }
}
