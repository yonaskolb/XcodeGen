//
//  Version.swift
//  ProjectSpec
//
//  Created by Yonas Kolb on 22/12/17.
//

import Foundation
import xcproj
import JSONUtilities

public struct PlatformVersions: Equatable {

    public var iOS: String?
    public var tvOS: String?
    public var watchOS: String?
    public var macOS: String?

    public init(iOS: String? = nil, tvOS: String? = nil, watchOS: String? = nil, macOS: String? = nil) {
        self.iOS = iOS
        self.tvOS = tvOS
        self.watchOS = watchOS
        self.macOS = macOS
    }

    public func version(for platform: Platform) -> String? {
        switch platform {
        case .iOS: return iOS
        case .tvOS: return tvOS
        case .watchOS: return watchOS
        case .macOS: return macOS
        }
    }

    public static func == (lhs: PlatformVersions, rhs: PlatformVersions) -> Bool {
        return lhs.iOS == rhs.iOS &&
            lhs.tvOS == rhs.tvOS &&
            lhs.watchOS == rhs.watchOS &&
            lhs.macOS == rhs.macOS
    }
}

extension Platform {

    public var versionBuildSetting: String {
        switch self {
        case .iOS: return "IPHONEOS_DEPLOYMENT_TARGET"
        case .tvOS: return "TVOS_DEPLOYMENT_TARGET"
        case .watchOS: return "WATCHOS_DEPLOYMENT_TARGET"
        case .macOS: return "MACOSX_DEPLOYMENT_TARGET"
        }
    }
}

extension PlatformVersions: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {

        func parseVersion(_ platform: String) -> String? {
            if let string: String = jsonDictionary.json(atKeyPath: .key(platform)) {
                return string
            } else if let double: Double = jsonDictionary.json(atKeyPath: .key(platform)) {
                return String(double)
            } else {
                return nil
            }
        }
        iOS = parseVersion("iOS")
        tvOS = parseVersion("tvOS")
        watchOS = parseVersion("watchOS")
        macOS = parseVersion("macOS")
    }
    
}
