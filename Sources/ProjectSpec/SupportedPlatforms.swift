import Foundation

public enum SupportedPlatforms: String, CaseIterable {
    case iOS
    case tvOS
    case macOS
    case macCatalyst
}

extension SupportedPlatforms {
    
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
        }
    }
}

extension SupportedPlatforms: JSONEncodable {
    
    public func toJSONValue() -> Any {
        return rawValue
    }
}
