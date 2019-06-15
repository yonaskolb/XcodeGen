import Foundation
import JSONUtilities
import PathKit

public struct SpecFile {
    public let basePath: Path
    public let relativePath: Path
    public let jsonDictionary: JSONDictionary
    public let subSpecs: [SpecFile]

    private let filename: String
    
    fileprivate struct Include {
        let path: Path
        let relativePaths: Bool

        static let defaultRelativePaths = true

        init?(any: Any) {
            if let string = any as? String {
                path = Path(string)
                relativePaths = Include.defaultRelativePaths
            } else if let dictionary = any as? JSONDictionary,
                let path = dictionary["path"] as? String {
                self.path = Path(path)
                relativePaths = dictionary["relativePaths"] as? Bool ?? Include.defaultRelativePaths
            } else {
                return nil
            }
        }

        static func parse(json: Any?) -> [Include] {
            if let array = json as? [Any] {
                return array.compactMap(Include.init)
            } else if let object = json, let include = Include(any: object) {
                return [include]
            } else {
                return []
            }
        }
    }

    public init(path: Path) throws {
        try self.init(filename: path.lastComponent, basePath: path.parent())
    }

    public init(filename: String, jsonDictionary: JSONDictionary, basePath: Path = "", relativePath: Path = "", subSpecs: [SpecFile] = []) {
        self.basePath = basePath
        self.relativePath = relativePath
        self.jsonDictionary = jsonDictionary
        self.subSpecs = subSpecs
        self.filename = filename
    }

    fileprivate init(include: Include, basePath: Path, relativePath: Path) throws {
        let basePath = include.relativePaths ? (basePath + relativePath) : (basePath + relativePath + include.path.parent())
        let relativePath = include.relativePaths ? include.path.parent() : Path()

        try self.init(filename: include.path.lastComponent, basePath: basePath, relativePath: relativePath)
    }

    fileprivate init(filename: String, basePath: Path, relativePath: Path = "") throws {
        let path = basePath + relativePath + filename
        let jsonDictionary = try SpecFile.loadDictionary(path: path)

        let includes = Include.parse(json: jsonDictionary["include"])
        let subSpecs: [SpecFile] = try includes.map { include in
            try SpecFile(include: include, basePath: basePath, relativePath: relativePath)
        }

        self.init(filename: filename, jsonDictionary: jsonDictionary, basePath: basePath, relativePath: relativePath, subSpecs: subSpecs)
    }

    static func loadDictionary(path: Path) throws -> JSONDictionary {
        // Depending on the extension we will either load the file as YAML or JSON
        if path.extension?.lowercased() == "json" {
            let data: Data = try path.read()
            let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            guard let jsonDictionary = jsonData as? [String: Any] else {
                fatalError("Invalid JSON at path \(path)")
            }
            return jsonDictionary
        } else {
            return try loadYamlDictionary(path: path)
        }
    }

    public func resolvedDictionary(variables: [String: String] = [:]) -> JSONDictionary {
        let resolvedDictionary = resolvedDictionaryWithUniqueTargets()
        return substitute(variables: variables, in: resolvedDictionary)
    }

    private func resolvedDictionaryWithUniqueTargets() -> JSONDictionary {
        let resolvedSpec = resolvingPaths()
        
        var value = Set<String>()
        return resolvedSpec.mergedDictionary(set: &value)
    }
    
    private func substitute(variables: [String: String], in mergedDictionary: JSONDictionary) -> JSONDictionary {
        var resolvedSpec = mergedDictionary
        
        for (key, value) in variables {
            resolvedSpec = resolvedSpec.replaceString("${\(key)}", with: value)
        }
        
        return resolvedSpec
    }
    
    func mergedDictionary(set mergedTargets: inout Set<String>) -> JSONDictionary {
        let name = (basePath + relativePath + Path(filename)).description
        
        guard !mergedTargets.contains(name) else { return [:] }
        mergedTargets.insert(name)
        
        return jsonDictionary.merged(onto:
            subSpecs
                .map { $0.mergedDictionary(set: &mergedTargets) }
                .reduce([:]) { $1.merged(onto: $0) })
    }

    func resolvingPaths(relativeTo basePath: Path = Path()) -> SpecFile {
        let relativePath = (basePath + self.relativePath).normalize()
        guard relativePath != Path() else {
            return self
        }

        let jsonDictionary = Project.pathProperties.resolvingPaths(in: self.jsonDictionary, relativeTo: relativePath)
        return SpecFile(
            filename: filename,
            jsonDictionary: jsonDictionary,
            relativePath: self.relativePath,
            subSpecs: subSpecs.map { $0.resolvingPaths(relativeTo: relativePath) }
        )
    }
}

extension Dictionary where Key == String, Value: Any {

    func merged(onto other: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
        var merged = other

        for (key, value) in self {
            if key.hasSuffix(":REPLACE") {
                let newKey = key[key.startIndex..<key.index(key.endIndex, offsetBy: -8)]
                merged[Key(newKey)] = value
            } else if let dictionary = value as? Dictionary<Key, Value>, let base = merged[key] as? Dictionary<Key, Value> {
                merged[key] = dictionary.merged(onto: base) as? Value
            } else if let array = value as? [Any], let base = merged[key] as? [Any] {
                merged[key] = (base + array) as? Value
            } else {
                merged[key] = value
            }
        }
        return merged
    }

    func replaceString(_ template: String, with replacement: String) -> JSONDictionary {
        var replaced: JSONDictionary = self
        for (key, value) in self {
            switch value {
            case let dictionary as JSONDictionary:
                replaced[key] = dictionary.replaceString(template, with: replacement)
            case let string as String:
                replaced[key] = string.replacingOccurrences(of: template, with: replacement)
            case let array as [JSONDictionary]:
                replaced[key] = array.map { $0.replaceString(template, with: replacement) }
            case let array as [String]:
                replaced[key] = array.map { $0.replacingOccurrences(of: template, with: replacement) }
            default: break
            }
        }
        return replaced
    }
}
