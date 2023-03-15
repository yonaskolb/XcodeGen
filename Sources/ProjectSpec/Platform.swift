import Foundation

public enum Platform: String, Hashable, CaseIterable {
    case iOS
    case watchOS
    case tvOS
    case macOS
}

public enum PlatformFilters: String, Equatable {
    case iOS
    case tvOS
}
