import Foundation
import JSONUtilities
import PathKit
import xcodeproj

public struct TargetSource: Equatable {

    public var path: String
    public var name: String?
    public var compilerFlags: [String]
    public var excludes: [String]
    public var type: SourceType?
    public var optional: Bool
    public var buildPhase: BuildPhase?
    public var headerVisibility: HeaderVisibility?

    public enum HeaderVisibility: String {
        case `public`
        case `private`
        case project

        public var settingName: String {
            switch self {
            case .public: return "Public"
            case .private: return "Private"
            case .project: return "Project"
            }
        }
    }

    public enum BuildPhase: String {
        case sources
        case headers
        case resources
        case none

        public var buildPhase: xcproj.BuildPhase? {
            switch self {
            case .sources: return .sources
            case .headers: return .headers
            case .resources: return .resources
            case .none: return nil
            }
        }
    }

    public enum SourceType: String {
        case group
        case file
        case folder
    }

    public init(
        path: String,
        name: String? = nil,
        compilerFlags: [String] = [],
        excludes: [String] = [],
        type: SourceType? = nil,
        optional: Bool = false,
        buildPhase: BuildPhase? = nil,
        headerVisibility: HeaderVisibility? = nil
    ) {
        self.path = path
        self.name = name
        self.compilerFlags = compilerFlags
        self.excludes = excludes
        self.type = type
        self.optional = optional
        self.buildPhase = buildPhase
    }
}

extension TargetSource: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self = TargetSource(path: value)
    }
}

extension TargetSource: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        name = jsonDictionary.json(atKeyPath: "name")

        let maybeCompilerFlagsString: String? = jsonDictionary.json(atKeyPath: "compilerFlags")
        let maybeCompilerFlagsArray: [String]? = jsonDictionary.json(atKeyPath: "compilerFlags")
        compilerFlags = maybeCompilerFlagsArray ??
            maybeCompilerFlagsString.map { $0.split(separator: " ").map { String($0) } } ?? []

        headerVisibility = jsonDictionary.json(atKeyPath: "headerVisibility")
        excludes = jsonDictionary.json(atKeyPath: "excludes") ?? []
        type = jsonDictionary.json(atKeyPath: "type")
        optional = jsonDictionary.json(atKeyPath: "optional") ?? false
        if let string: String = jsonDictionary.json(atKeyPath: "buildPhase") {
            if let buildPhase = BuildPhase(rawValue: string) {
                self.buildPhase = buildPhase
            } else {
                throw SpecParsingError.unknownSourceBuildPhase(string)
            }
        }
    }
}
