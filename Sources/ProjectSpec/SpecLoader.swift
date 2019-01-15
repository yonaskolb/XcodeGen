import Foundation
import JSONUtilities
import PathKit
import Yams

extension Project {
    
    public init(path: Path) throws {
        let basePath = path.parent()
        let template = try Spec(filename: path.lastComponent, basePath: basePath)
        try self.init(spec: template, basePath: basePath)
    }

    @available(*, deprecated, message: "Use `Project.Spec` for loading files from disk.")
    public static func loadDictionary(path: Path) throws -> JSONDictionary {
        return try Project.Spec(filename: path.lastComponent, basePath: path.parent()).jsonDictionary
    }
}

protocol PathContaining {

    associatedtype JSONSourceType
    static func expandPaths(for source: JSONSourceType, relativeTo path: Path) -> JSONSourceType
}

extension PathContaining {

    static func expandStringPaths(from source: JSONDictionary, forKey key: String, relativeTo path: Path) -> JSONDictionary {
        var result = source

        if let source = result[key] as? String {
            result[key] = (path + source).string
        } else if let source = result[key] as? [String] {
            result[key] = source.map { (path + $0).string }
        } else if let source = result[key] as? [String: String] {
            result[key] = source.mapValues { (path + $0).string }
        }
        return result
    }
    
    static func expandChildPaths<T: PathContaining>(from source: JSONDictionary, forKey key: String, relativeTo path: Path, type: T.Type) -> JSONDictionary {
        var result = source

        if let source = result[key] as? T.JSONSourceType {
            result[key] = T.expandPaths(for: source, relativeTo: path)
        } else if let source = result[key] as? [T.JSONSourceType] {
            result[key] = source.map { T.expandPaths(for: $0, relativeTo: path) }
        } else if let source = result[key] as? [String: T.JSONSourceType] {
            result[key] = source.mapValues { T.expandPaths(for: $0, relativeTo: path) }
        }
        return result
    }

    static func expandChildPaths<T: PathContaining>(from source: JSONDictionary, forPotentialKeys keys: [String], relativeTo path: Path, type: T.Type) -> JSONDictionary {
        var result = source

        for key in keys {
            result = expandChildPaths(from: result, forKey: key, relativeTo: path, type: type)
        }
        return result
    }
}
