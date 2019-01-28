import Foundation
import JSONUtilities
import PathKit

public struct Spec {
    public let relativePath: Path
    public let jsonDictionary: JSONDictionary
    public let subSpecs: [Spec]

    public init(relativePath: Path, jsonDictionary: JSONDictionary, subSpecs: [Spec] = []) {
        self.relativePath = relativePath
        self.jsonDictionary = jsonDictionary
        self.subSpecs = subSpecs
    }

    public init(filename: String, basePath: Path, relativePath: Path = Path()) throws {
        let path = basePath + relativePath + filename

        // Depending on the extension we will either load the file as YAML or JSON
        var json: [String: Any]
        if path.extension?.lowercased() == "json" {
            let data: Data = try path.read()
            let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            guard let jsonDictionary = jsonData as? [String: Any] else {
                fatalError("Invalid JSON at path \(path)")
            }
            json = jsonDictionary
        } else {
            json = try loadYamlDictionary(path: path)
        }

        let processIncludeOption = { (option: Any) -> (String, Bool)? in
            if let option = option as? String {
                return (option, true)
            } else if let option = option as? JSONDictionary, let path = option["path"] as? String {
                return (path, (option["relativePaths"] as? Bool) ?? true)
            }
            return nil
        }

        let includeSources: [(String, Bool)]
        if let sources = json["include"] as? [Any] {
            includeSources = sources.compactMap { processIncludeOption($0) }
        } else if let source = json["include"] {
            includeSources = [processIncludeOption(source)].compactMap { $0 }
        } else {
            includeSources = []
        }

        let includes = try includeSources.map { include -> Spec in
            let path = Path(include.0)
            let basePath = include.1 ? basePath + relativePath : basePath + relativePath + path.parent()
            let relativePath = include.1 ? path.parent() : Path()

            return try Spec(filename: path.lastComponent, basePath: basePath, relativePath: relativePath)
        }

        self.relativePath = relativePath
        self.jsonDictionary = json
        self.subSpecs = includes
    }

    public func resolvedDictionary() -> JSONDictionary {
        return jsonDictionary.merged(onto:
            subSpecs
                .map { $0.resolvedDictionary() }
                .reduce([:]) { $1.merged(onto: $0) }
        )
    }
}

extension Spec {
    
    func resolvingPaths(relativeTo basePath: Path = Path()) -> Spec {
        let relativePath = (basePath + self.relativePath).normalize()
        guard relativePath != Path() else {
            return self
        }

        let jsonDictionary = Project.pathProperties.resolvingPaths(in: self.jsonDictionary, relativeTo: relativePath)

        return Spec(
            relativePath: self.relativePath,
            jsonDictionary: jsonDictionary,
            subSpecs: self.subSpecs.map { template in
                return template.resolvingPaths(relativeTo: relativePath)
            }
        )
    }
}

extension Dictionary where Key == String, Value: Any {

    func merged(onto other: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
        var merged = other

        for (key, value) in self {
            if key.hasSuffix(":REPLACE") {
                let newKey = key[key.startIndex ..< key.index(key.endIndex, offsetBy: -8)]
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
