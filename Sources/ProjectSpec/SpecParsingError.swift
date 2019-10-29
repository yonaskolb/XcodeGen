import Foundation

public enum SpecParsingError: Error, CustomStringConvertible {
    case unknownTargetType(String)
    case unknownTargetPlatform(String)
    case invalidDependency([String: Any])
    case unknownPackageRequirement([String: Any])
    case invalidSourceBuildPhase(String)
    case invalidTargetReference(String)
    case invalidVersion(String)

    public var description: String {
        switch self {
        case let .unknownTargetType(type):
            return "Unknown Target type: \(type)"
        case let .unknownTargetPlatform(platform):
            return "Unknown Target platform: \(platform)"
        case let .invalidDependency(dependency):
            return "Unknown Target dependency: \(dependency)"
        case let .invalidSourceBuildPhase(error):
            return "Invalid Source Build Phase: \(error)"
        case let .invalidTargetReference(targetReference):
            return "Invalid Target Reference Syntax: \(targetReference)"
        case let .invalidVersion(version):
            return "Invalid version: \(version)"
        case let .unknownPackageRequirement(package):
            return "Unknown package requirement: \(package)"
        }
    }
}
