import Foundation
import JSONUtilities
import PathKit
import xcproj

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
                
                public var destination: xcproj.PBXCopyFilesBuildPhase.SubFolder? {
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
            
            public var destination: Destination
            public var subpath: String
        }

        public var buildPhase: xcproj.BuildPhase? {
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
            buildPhase = try BuildPhase(string: string)
        } else if let dict: JSONDictionary = jsonDictionary.json(atKeyPath: "buildPhase") {
            buildPhase = try BuildPhase(jsonDictionary: dict)
        }
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

extension TargetSource.BuildPhase.CopyFilesSettings: JSONObjectConvertible {
    
    public init(jsonDictionary: JSONDictionary) throws {
        destination = try jsonDictionary.json(atKeyPath: "destination")
        subpath = jsonDictionary.json(atKeyPath: "subpath") ?? ""
    }
}
