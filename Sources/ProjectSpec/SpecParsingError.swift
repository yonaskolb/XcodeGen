import Foundation

public enum SpecParsingError: Error, CustomStringConvertible {
    case unknownTargetType(String)
    case unknownTargetPlatform(String)
    case invalidDependency([String: Any])

    public var description: String {
        switch self {
        case let .unknownTargetType(type): return "Unknown Target type: \(type)"
        case let .unknownTargetPlatform(platform): return "Unknown Target platform: \(platform)"
        case let .invalidDependency(dependency): return "Unknown Target dependency: \(dependency)"
        }
    }
}
