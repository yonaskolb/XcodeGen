import Foundation
import JSONUtilities
import PathKit

public struct SpecFile {
    public let basePath: Path
    public let relativePath: Path
    public let jsonDictionary: JSONDictionary
    public let subSpecs: [SpecFile]

    private let filePath: Path

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
        try self.init(filePath: path, basePath: path.parent())
    }

    public init(filePath: Path, jsonDictionary: JSONDictionary, basePath: Path = "", relativePath: Path = "", subSpecs: [SpecFile] = []) {
        self.basePath = basePath
        self.relativePath = relativePath
        self.jsonDictionary = jsonDictionary
        self.subSpecs = subSpecs
        self.filePath = filePath
    }

    private init(include: Include, basePath: Path, relativePath: Path) throws {
        let basePath = include.relativePaths ? (basePath + relativePath) : (basePath + relativePath + include.path.parent())
        let relativePath = include.relativePaths ? include.path.parent() : Path()

        try self.init(filePath: include.path, basePath: basePath, relativePath: relativePath)
    }

    private init(filePath: Path, basePath: Path, relativePath: Path = "") throws {
        let path = basePath + relativePath + filePath.lastComponent
        let jsonDictionary = try SpecFile.loadDictionary(path: path)

        let includes = Include.parse(json: jsonDictionary["include"])
        let subSpecs: [SpecFile] = try includes.map { include in
            try SpecFile(include: include, basePath: basePath, relativePath: relativePath)
        }

        self.init(filePath: filePath, jsonDictionary: jsonDictionary, basePath: basePath, relativePath: relativePath, subSpecs: subSpecs)
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
        resolvedDictionaryWithUniqueTargets().expand(variables: variables)
    }

    private func resolvedDictionaryWithUniqueTargets() -> JSONDictionary {
        let resolvedSpec = resolvingPaths()

        var value = Set<String>()
        return resolvedSpec.mergedDictionary(set: &value)
    }

    func mergedDictionary(set mergedTargets: inout Set<String>) -> JSONDictionary {
        let name = filePath.description

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
            filePath: filePath,
            jsonDictionary: jsonDictionary,
            relativePath: self.relativePath,
            subSpecs: subSpecs.map { $0.resolvingPaths(relativeTo: relativePath) }
        )
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
