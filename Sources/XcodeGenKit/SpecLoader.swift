//
//  SpecLoader.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 30/8/17.
//
//

import Foundation
import ProjectSpec
import PathKit
import Yams
import JSONUtilities

public struct SpecLoader {

    public static func loadSpec(path: Path) throws -> ProjectSpec {
        let dictionary = try loadDictionary(path: path)
        return try ProjectSpec(basePath: path.parent(), jsonDictionary: dictionary)
    }

    private static func loadDictionary(path: Path) throws -> JSONDictionary {
        var json = try loadYamlDictionary(path: path)

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
