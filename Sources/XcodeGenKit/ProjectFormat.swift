public extension ProjectFormat {
    static let `default`: ProjectFormat = .xcode16_0
}

public enum ProjectFormat: String {
    case xcode16_3
    case xcode16_0
    case xcode15_3
    case xcode15_0
    case xcode14_0

    public var objectVersion: UInt {
        switch self {
        case .xcode16_3: 90
        case .xcode16_0: 77
        case .xcode15_3: 63
        case .xcode15_0: 60
        case .xcode14_0: 56
        }
    }

    public var preferredProjectObjectVersion: UInt? {
        switch self {
        case .xcode16_3, .xcode16_0: objectVersion
        case .xcode15_3, .xcode15_0, .xcode14_0: nil
        }
    }

    public var compatibilityVersion: String? {
        switch self {
        case .xcode16_3, .xcode16_0: nil
        case .xcode15_3: "Xcode 15.3"
        case .xcode15_0: "Xcode 15.0"
        case .xcode14_0: "Xcode 14.0"
        }
    }
}
