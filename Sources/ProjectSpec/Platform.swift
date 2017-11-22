import Foundation

public enum Platform: String {
    case iOS
    case watchOS
    case tvOS
    case macOS
    public var carthageDirectoryName: String {
        switch self {
        case .macOS:
            return "Mac"
        default:
            return rawValue
        }
    }
}
