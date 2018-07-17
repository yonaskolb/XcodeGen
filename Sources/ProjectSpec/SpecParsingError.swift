import Foundation

public enum SpecParsingError: Error, CustomStringConvertible {
    case unknownTargetType(String)
    case unknownTargetPlatform(String)
    case invalidDependency([String: Any])
    case unknownSourceBuildPhase(String)
    case invalidSourceCopyFilesPhase
    case invalidVersion(String)

    public var description: String {
        switch self {
        case let .unknownTargetType(type):
            return "Unknown Target type: \(type)"
        case let .unknownTargetPlatform(platform):
            return "Unknown Target platform: \(platform)"
        case let .invalidDependency(dependency):
            return "Unknown Target dependency: \(dependency)"
        case let .unknownSourceBuildPhase(buildPhase):
            return "Unknown Source Build Phase: \(buildPhase)"
        case .invalidSourceCopyFilesPhase:
            return "copyFiles Build Phase without a copyFiles section"
        case let .invalidVersion(version):
            return "Invalid version: \(version)"
        }
    }
}
