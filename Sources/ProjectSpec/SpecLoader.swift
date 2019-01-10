import Foundation
import JSONUtilities
import PathKit
import Yams

extension Project {

    public init(path: Path) throws {
        let dictionary = try Project.loadDictionary(path: path)
        try self.init(basePath: path.parent(), jsonDictionary: dictionary)
    }

    public static func loadDictionary(path: Path) throws -> JSONDictionary {

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

        var includes: [String]
        if let includeString = json["include"] as? String {
            includes = [includeString]
        } else if let includeArray = json["include"] as? [String] {
            includes = includeArray
        } else {
            includes = []
        }

        if !includes.isEmpty {
            var includeDictionary: JSONDictionary = [:]
            for include in includes {
                let includePath = path.parent() + include
                let dictionary = try loadDictionary(path: includePath)
                includeDictionary = merge(dictionary: dictionary, onto: includeDictionary)
            }
            json = merge(dictionary: json, onto: includeDictionary)
        }

        let basePath = path.parent()
        json = expandPaths(in: json, basePath: basePath)

        return json
    }

    private static func expandPaths(in source: Dictionary<String, Any>, basePath: Path) -> Dictionary<String, Any> {
        var result = source

        for (key, value) in source {
            if let value = value as? String {
                result[key] = value.replacingOccurrences(of: "$(CURDIR)", with: basePath.string)
            } else if let value = value as? Array<Any> {
                result[key] = expandPaths(in: value, basePath: basePath)
            } else if let value = value as? Dictionary<String, Any> {
                result[key] = expandPaths(in: value, basePath: basePath)
            }
        }

        return result
    }

    private static func expandPaths(in source: Array<Any>, basePath: Path) -> Array<Any> {
        var result = source

        for (index, value) in source.enumerated() {
            if let value = value as? String {
                result[index] = value.replacingOccurrences(of: "$(CURDIR)", with: basePath.string)
            } else if let value = value as? Array<Any> {
                result[index] = expandPaths(in: value, basePath: basePath)
            } else if let value = value as? Dictionary<String, Any> {
                result[index] = expandPaths(in: value, basePath: basePath)
            }
        }

        return result
    }
}
