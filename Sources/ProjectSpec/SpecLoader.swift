import Foundation
import JSONUtilities
import PathKit
import Yams

extension Project {

    public init(path: Path) throws {
        let dictionary = try Project.loadDictionary(path: path)
        try self.init(basePath: path.parent(), jsonDictionary: dictionary)
    }

    private static func loadDictionary(path: Path) throws -> JSONDictionary {

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
        return json
    }

    private static func merge(dictionary: JSONDictionary, onto base: JSONDictionary) -> JSONDictionary {
        var merged = base

        for (key, value) in dictionary {
            if key.hasSuffix(":REPLACE") {
                let newKey = key.replacingOccurrences(of: ":REPLACE", with: "")
                merged[newKey] = value
            } else if let dictionary = value as? JSONDictionary, let base = merged[key] as? JSONDictionary {
                merged[key] = merge(dictionary: dictionary, onto: base)
            } else if let array = value as? [Any], let base = merged[key] as? [Any] {
                merged[key] = base + array
            } else {
                merged[key] = value
            }
        }
        return merged
    }
}
