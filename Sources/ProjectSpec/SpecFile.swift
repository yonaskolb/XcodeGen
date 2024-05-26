import Foundation
import JSONUtilities
import PathKit
import XcodeGenCore
import Yams

public struct SpecFile {
    /// For the root spec, this is the folder containing the SpecFile. For subSpecs this is the path
    /// to the folder of the parent spec that is including this SpecFile.
    public let basePath: Path
    public let jsonDictionary: JSONDictionary
    public let subSpecs: [SpecFile]

    /// The relative path to use when resolving paths in the json dictionary. Is an empty path when
    /// included with relativePaths disabled.
    private let relativePath: Path
    
    /// The path to the file relative to the basePath.
    private let filePath: Path

    fileprivate struct Include {
        let path: Path
        let relativePaths: Bool
        let enable: Bool

        static let defaultRelativePaths = true
        static let defaultEnable = true

        init?(any: Any) {
            if let path = any as? String {
                self.init(
                    path: Path(path),
                    relativePaths: Include.defaultRelativePaths,
                    enable: Include.defaultEnable
                )
            } else if let dictionary = any as? JSONDictionary, let path = dictionary["path"] as? String {
                self.init(
                    path: Path(path),
                    dictionary: dictionary
                )
            } else {
                return nil
            }
        }
        
        private init(path: Path, relativePaths: Bool, enable: Bool) {
            self.path = path
            self.relativePaths = relativePaths
            self.enable = enable
        }
        
        private init?(path: Path, dictionary: JSONDictionary) {
            self.path = path
            relativePaths = Self.resolveBoolean(dictionary, key: "relativePaths") ?? Include.defaultRelativePaths
            enable = Self.resolveBoolean(dictionary, key: "enable") ?? Include.defaultEnable
        }
        
        private static func includes(from array: [Any], basePath: Path) -> [Include] {
            array.flatMap { entry -> [Include] in
                if let string = entry as? String, let include = Include(any: string) {
                   return [include]
                } else if let dictionary = entry as? JSONDictionary, let path = dictionary["path"] as? String {
                    return Glob(pattern: (basePath + Path(path)).normalize().string)
                        .compactMap { Include(path: Path($0), dictionary: dictionary) }
                } else {
                    return []
                }
            }
        }

        static func parse(json: Any?, basePath: Path) -> [Include] {
            if let array = json as? [Any] {
                return includes(from: array, basePath: basePath)
            } else if let object = json, let include = Include(any: object) {
                return [include]
            } else {
                return []
            }
        }

        private static func resolveBoolean(_ dictionary: [String: Any], key: String) -> Bool? {
            dictionary[key] as? Bool ?? (dictionary[key] as? NSString)?.boolValue
        }
    }
    
    /// Create a SpecFile for a Project
    /// - Parameters:
    ///   - path: The absolute path to the spec file
    ///   - projectRoot: The root of the project to use as the base path. When nil, uses the parent
    ///     of the path.
    public init(path: Path, projectRoot: Path? = nil, variables: [String: String] = [:]) throws {
        let basePath = projectRoot ?? path.parent()
        let filePath = try path.relativePath(from: basePath)
        var cachedSpecFiles: [Path: SpecFile] = [:]
        
        try self.init(filePath: filePath, basePath: basePath, cachedSpecFiles: &cachedSpecFiles, variables: variables)
    }
    
    /// Memberwise initializer for SpecFile
    public init(filePath: Path, jsonDictionary: JSONDictionary, basePath: Path = "", relativePath: Path = "", subSpecs: [SpecFile] = []) {
        self.basePath = basePath
        self.relativePath = relativePath
        self.jsonDictionary = jsonDictionary
        self.subSpecs = subSpecs
        self.filePath = filePath
    }

    private init(include: Include, basePath: Path, relativePath: Path, cachedSpecFiles: inout [Path: SpecFile], variables: [String: String]) throws {
        let basePath = include.relativePaths ? (basePath + relativePath) : basePath
        let relativePath = include.relativePaths ? include.path.parent() : Path()

        try self.init(filePath: include.path, basePath: basePath, cachedSpecFiles: &cachedSpecFiles, variables: variables, relativePath: relativePath)
    }

    private init(filePath: Path, basePath: Path, cachedSpecFiles: inout [Path: SpecFile], variables: [String: String], relativePath: Path = "") throws {
        let path = basePath + filePath
        if let specFile = cachedSpecFiles[path] {
            self = specFile
            return
        }

        let jsonDictionary = try SpecFile.loadDictionary(path: path).expand(variables: variables)

        let includes = Include.parse(json: jsonDictionary["include"], basePath: basePath)
        let subSpecs: [SpecFile] = try includes
            .filter(\.enable)
            .map { include in
                return try SpecFile(include: include, basePath: basePath, relativePath: relativePath, cachedSpecFiles: &cachedSpecFiles, variables: variables)
            }

        self.init(filePath: filePath, jsonDictionary: jsonDictionary, basePath: basePath, relativePath: relativePath, subSpecs: subSpecs)
        cachedSpecFiles[path] = self
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

    public func resolvedDictionary() -> JSONDictionary {
        resolvedDictionaryWithUniqueTargets()
    }

    private func resolvedDictionaryWithUniqueTargets() -> JSONDictionary {
        var cachedSpecFiles: [Path: SpecFile] = [:]
        let resolvedSpec = resolvingPaths(cachedSpecFiles: &cachedSpecFiles)

        var mergedSpecPaths = Set<Path>()
        return resolvedSpec.mergedDictionary(set: &mergedSpecPaths)
    }

    private func mergedDictionary(set mergedSpecPaths: inout Set<Path>) -> JSONDictionary {
        let path = basePath + filePath

        guard mergedSpecPaths.insert(path).inserted else { return [:] }

        return jsonDictionary.merged(onto:
            subSpecs
                .map { $0.mergedDictionary(set: &mergedSpecPaths) }
                .reduce([:]) { $1.merged(onto: $0) })
    }

    private func resolvingPaths(cachedSpecFiles: inout [Path: SpecFile], relativeTo basePath: Path = Path()) -> SpecFile {
        let path = basePath + filePath
        if let cachedSpecFile = cachedSpecFiles[path] {
            return cachedSpecFile
        }

        let relativePath = (basePath + self.relativePath).normalize()
        guard relativePath != Path() else {
            return self
        }

        let jsonDictionary = Project.pathProperties.resolvingPaths(in: self.jsonDictionary, relativeTo: relativePath)
        let specFile = SpecFile(
            filePath: filePath,
            jsonDictionary: jsonDictionary,
            basePath: self.basePath,
            relativePath: self.relativePath,
            subSpecs: subSpecs.map { $0.resolvingPaths(cachedSpecFiles: &cachedSpecFiles, relativeTo: relativePath) }
        )
        cachedSpecFiles[path] = specFile
        return specFile
    }
}

extension Dictionary where Key == String, Value: Any {

    func merged(onto other: [Key: Value]) -> [Key: Value] {
        var merged = other

        for (key, value) in self {
            if key.hasSuffix(":REPLACE") {
                let newKey = key[key.startIndex..<key.index(key.endIndex, offsetBy: -8)]
                merged[Key(newKey)] = value
            } else if let dictionary = value as? [Key: Value], let base = merged[key] as? [Key: Value] {
                merged[key] = dictionary.merged(onto: base) as? Value
            } else if let array = value as? [Any], let base = merged[key] as? [Any] {
                merged[key] = (base + array) as? Value
            } else {
                merged[key] = value
            }
        }
        return merged
    }

    func expand(variables: [String: String]) -> JSONDictionary {
        var expanded: JSONDictionary = self

        if !variables.isEmpty {
            for (key, value) in self {
                let newKey = expand(variables: variables, in: key)
                if newKey != key {
                    expanded.removeValue(forKey: key)
                }
                expanded[newKey] = expand(variables: variables, in: value)
            }
        }

        return expanded
    }

    private func expand(variables: [String: String], in value: Any) -> Any {
        switch value {
        case let dictionary as JSONDictionary:
            return dictionary.expand(variables: variables)
        case let string as String:
            return expand(variables: variables, in: string)
        case let array as [JSONDictionary]:
            return array.map { $0.expand(variables: variables) }
        case let array as [String]:
            return array.map { self.expand(variables: variables, in: $0) }
        case let anyArray as [Any]:
            return anyArray.map { self.expand(variables: variables, in: $0) }
        default:
            return value
        }
    }

    private func expand(variables: [String: String], in string: String) -> String {
        var result = string
        var index = result.startIndex

        while index < result.endIndex {
            let substring = result[index...]

            if substring.count < 4 {
                // We need at least 4 characters: ${x}
                index = result.endIndex
            } else if substring[index] == "$"
                && substring[substring.index(index, offsetBy: 1)] == "{"
                && substring[substring.index(index, offsetBy: 2)] != "}" {
                // This is the start of a variable expansion...
                let variableStart = index
                if let variableEnd = substring.firstIndex(of: "}") {
                    // ...with an end
                    let nameStart = result.index(variableStart, offsetBy: 2) // Skipping ${
                    let nameEnd = result.index(variableEnd, offsetBy: -1) // Removing trailing }

                    let name = result[nameStart...nameEnd]

                    if let value = variables[String(name)] {
                        result.replaceSubrange(variableStart...variableEnd, with: value)
                        index = result.index(index, offsetBy: value.count)
                    } else {
                        // Skip this whole variable for which we don't have a value
                        index = result.index(after: variableEnd)
                    }
                } else {
                    // Malformed variable, skip the whole string
                    index = result.endIndex
                }
            } else {
                // Move on to the next $ and start again or finish early
                index = result[result.index(after: index)...].firstIndex(of: "$") ?? result.endIndex
            }
        }

        return result
    }
}
