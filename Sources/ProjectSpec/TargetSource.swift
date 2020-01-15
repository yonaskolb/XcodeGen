import Foundation
import JSONUtilities
import PathKit
import enum XcodeProj.BuildPhase
import class XcodeProj.PBXCopyFilesBuildPhase

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
    public var buildPhase: BuildPhase?
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

    public enum BuildPhase: Equatable {
        case sources
        case headers
        case resources
        case copyFiles(CopyFilesSettings)
        case none
        // Not currently exposed as selectable options, but used internally
        case frameworks
        case runScript
        case carbonResources

        public struct CopyFilesSettings: Equatable, Hashable {
            public static let xpcServices = CopyFilesSettings(
                destination: .productsDirectory,
                subpath: "$(CONTENTS_FOLDER_PATH)/XPCServices",
                phaseOrder: .postCompile
            )

            public enum Destination: String {
                case absolutePath
                case productsDirectory
                case wrapper
                case executables
                case resources
                case javaResources
                case frameworks
                case sharedFrameworks
                case sharedSupport
                case plugins

                public var destination: PBXCopyFilesBuildPhase.SubFolder? {
                    switch self {
                    case .absolutePath: return .absolutePath
                    case .productsDirectory: return .productsDirectory
                    case .wrapper: return .wrapper
                    case .executables: return .executables
                    case .resources: return .resources
                    case .javaResources: return .javaResources
                    case .frameworks: return .frameworks
                    case .sharedFrameworks: return .sharedFrameworks
                    case .sharedSupport: return .sharedSupport
                    case .plugins: return .plugins
                    }
                }
            }

            public enum PhaseOrder: String {
                /// Run before the Compile Sources phase
                case preCompile
                /// Run after the Compile Sources and post-compile Run Script phases
                case postCompile
            }

            public var destination: Destination
            public var subpath: String
            public var phaseOrder: PhaseOrder

            public init(
                destination: Destination,
                subpath: String,
                phaseOrder: PhaseOrder
            ) {
                self.destination = destination
                self.subpath = subpath
                self.phaseOrder = phaseOrder
            }
        }

        public var buildPhase: XcodeProj.BuildPhase? {
            switch self {
            case .sources: return .sources
            case .headers: return .headers
            case .resources: return .resources
            case .copyFiles: return .copyFiles
            case .frameworks: return .frameworks
            case .runScript: return .runScript
            case .carbonResources: return .carbonResources
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
        group: String? = nil,
        compilerFlags: [String] = [],
        excludes: [String] = [],
        includes: [String] = [],
        type: SourceType? = nil,
        optional: Bool = optionalDefault,
        buildPhase: BuildPhase? = nil,
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
            buildPhase = try BuildPhase(string: string)
        } else if let dict: JSONDictionary = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhase(jsonDictionary: dict)
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
        ]

        if optional != TargetSource.optionalDefault {
            dict["optional"] = optional
        }

        if dict.count == 0 {
            return path
        }

        dict["path"] = path

        return dict
    }
}

extension TargetSource.BuildPhase {

    public init(string: String) throws {
        switch string {
        case "sources": self = .sources
        case "headers": self = .headers
        case "resources": self = .resources
        case "copyFiles":
            throw SpecParsingError.invalidSourceBuildPhase("copyFiles must specify a \"destination\" and optional \"subpath\"")
        case "none": self = .none
        default:
            throw SpecParsingError.invalidSourceBuildPhase(string.quoted)
        }
    }
}

extension TargetSource.BuildPhase: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        self = .copyFiles(try jsonDictionary.json(atKeyPath: "copyFiles"))
    }
}

extension TargetSource.BuildPhase: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .sources: return "sources"
        case .headers: return "headers"
        case .resources: return "resources"
        case .copyFiles(let files): return ["copyFiles": files.toJSONValue()]
        case .none: return "none"
        case .frameworks: fatalError("invalid build phase")
        case .runScript: fatalError("invalid build phase")
        case .carbonResources: fatalError("invalid build phase")
        }
    }
}

extension TargetSource.BuildPhase.CopyFilesSettings: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        destination = try jsonDictionary.json(atKeyPath: "destination")
        subpath = jsonDictionary.json(atKeyPath: "subpath") ?? ""
        phaseOrder = .postCompile
    }
}

extension TargetSource.BuildPhase.CopyFilesSettings: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "destination": destination.rawValue,
            "subpath": subpath,
        ]
    }
}

extension TargetSource: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("path"),
        ]
    }
}
