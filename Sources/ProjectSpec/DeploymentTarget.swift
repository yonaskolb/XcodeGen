import Foundation
import JSONUtilities
import Version

public struct DeploymentTarget: Equatable {

    public var iOS: Version?
    public var tvOS: Version?
    public var watchOS: Version?
    public var macOS: Version?

    public init(
        iOS: Version? = nil,
        tvOS: Version? = nil,
        watchOS: Version? = nil,
        macOS: Version? = nil
    ) {
        self.iOS = iOS
        self.tvOS = tvOS
        self.watchOS = watchOS
        self.macOS = macOS
    }

    public func version(for platform: Platform) -> Version? {
        switch platform {
        case .iOS: return iOS
        case .tvOS: return tvOS
        case .watchOS: return watchOS
        case .macOS: return macOS
        }
    }
}

extension Platform {

    public var deploymentTargetSetting: String {
        switch self {
        case .iOS: return "IPHONEOS_DEPLOYMENT_TARGET"
        case .tvOS: return "TVOS_DEPLOYMENT_TARGET"
        case .watchOS: return "WATCHOS_DEPLOYMENT_TARGET"
        case .macOS: return "MACOSX_DEPLOYMENT_TARGET"
        }
    }

    public var sdkRoot: String {
        switch self {
        case .iOS: return "iphoneos"
        case .tvOS: return "appletvos"
        case .watchOS: return "watchos"
        case .macOS: return "macosx"
        }
    }
}

extension Version {

    /// doesn't print patch if 0
    public var deploymentTarget: String {
        "\(major).\(minor)\(patch > 0 ? ".\(patch)" : "")"
    }
}

extension DeploymentTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {

        func parseVersion(_ platform: String) throws -> Version? {
            if let string: String = jsonDictionary.json(atKeyPath: .key(platform)) {
                return try Version.parse(string)
            } else if let double: Double = jsonDictionary.json(atKeyPath: .key(platform)) {
                return try Version.parse(double)
            } else {
                return nil
            }
        }
        iOS = try parseVersion("iOS")
        tvOS = try parseVersion("tvOS")
        watchOS = try parseVersion("watchOS")
        macOS = try parseVersion("macOS")
    }
}

extension DeploymentTarget: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "iOS": iOS?.description,
            "tvOS": tvOS?.description,
            "watchOS": watchOS?.description,
            "macOS": macOS?.description,
        ]
    }
}
