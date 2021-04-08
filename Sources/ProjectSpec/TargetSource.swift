import Foundation
import JSONUtilities
import PathKit

public struct TargetSource: Equatable {
    public static let optionalDefault = false

    public var path: String
    public var name: String?
    public var group: String?
    public var compilerFlags: [String]
    public var excludes: [String]
    public var includes: [String]
    public var type: SourceType?
    public var optional: Bool
    public var buildPhase: BuildPhaseSpec?
    public var headerVisibility: HeaderVisibility?
    public var createIntermediateGroups: Bool?
    public var attributes: [String]
    public var resourceTags: [String]

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

    public init(
        path: String,
        name: String? = nil,
        group: String? = nil,
        compilerFlags: [String] = [],
        excludes: [String] = [],
        includes: [String] = [],
        type: SourceType? = nil,
        optional: Bool = optionalDefault,
        buildPhase: BuildPhaseSpec? = nil,
        headerVisibility: HeaderVisibility? = nil,
        createIntermediateGroups: Bool? = nil,
        attributes: [String] = [],
        resourceTags: [String] = []
    ) {
        self.path = path
        self.name = name
        self.group = group
        self.compilerFlags = compilerFlags
        self.excludes = excludes
        self.includes = includes
        self.type = type
        self.optional = optional
        self.buildPhase = buildPhase
        self.headerVisibility = headerVisibility
        self.createIntermediateGroups = createIntermediateGroups
        self.attributes = attributes
        self.resourceTags = resourceTags
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
        group = jsonDictionary.json(atKeyPath: "group")

        let maybeCompilerFlagsString: String? = jsonDictionary.json(atKeyPath: "compilerFlags")
        let maybeCompilerFlagsArray: [String]? = jsonDictionary.json(atKeyPath: "compilerFlags")
        compilerFlags = maybeCompilerFlagsArray ??
            maybeCompilerFlagsString.map { $0.split(separator: " ").map { String($0) } } ?? []

        headerVisibility = jsonDictionary.json(atKeyPath: "headerVisibility")
        excludes = jsonDictionary.json(atKeyPath: "excludes") ?? []
        includes = jsonDictionary.json(atKeyPath: "includes") ?? []
        type = jsonDictionary.json(atKeyPath: "type")
        optional = jsonDictionary.json(atKeyPath: "optional") ?? TargetSource.optionalDefault

        if let string: String = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhaseSpec(string: string)
        } else if let dict: JSONDictionary = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhaseSpec(jsonDictionary: dict)
        }

        createIntermediateGroups = jsonDictionary.json(atKeyPath: "createIntermediateGroups")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? []
        resourceTags = jsonDictionary.json(atKeyPath: "resourceTags") ?? []
    }
}

extension TargetSource: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "compilerFlags": compilerFlags,
            "excludes": excludes,
            "includes": includes,
            "name": name,
            "group": group,
            "headerVisibility": headerVisibility?.rawValue,
            "type": type?.rawValue,
            "buildPhase": buildPhase?.toJSONValue(),
            "createIntermediateGroups": createIntermediateGroups,
            "resourceTags": resourceTags,
            "path": path,
        ]

        if optional != TargetSource.optionalDefault {
            dict["optional"] = optional
        }

        return dict
    }
}

extension TargetSource: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("path"),
        ]
    }
}
