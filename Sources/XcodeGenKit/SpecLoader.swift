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
        let filteredDictionary = SpecLoader.filterNull(dictionary) as! [String:Any]
        return try ProjectSpec(jsonDictionary: filteredDictionary)
    }

    private static func loadDictionary(path: Path) throws -> JSONDictionary {
        let string: String = try path.read()
        let yaml = try Yams.load(yaml: string)
        guard var json = yaml as? JSONDictionary else {
            throw JSONUtilsError.fileNotAJSONDictionary
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
            if let dictionary = value as? JSONDictionary, let base = merged[key] as? JSONDictionary {
                merged[key] = merge(dictionary: dictionary, onto: base)
            } else if let array = value as? [Any], let base = merged[key] as? [Any] {
                merged[key] = base + array
            } else {
                merged[key] = value
            }
        }
        return merged
    }

    private static func filterNull(_ object:Any) -> Any {
        var returnedValue : Any = object
        if let dict = object as? [String:Any] {
            var mutabledic : [String: Any] = [:]
            for (key, value) in dict {
                mutabledic[key] = SpecLoader.filterNull(value)
            }
            returnedValue = mutabledic
        }
        else if let array = object as? [Any] {
            var mutableArray: [Any] = array
            for (index, value) in array.enumerated() {
                mutableArray[index] = SpecLoader.filterNull(value)
            }
            returnedValue = mutableArray
        }
        return (object is NSNull) ? "" : returnedValue
    }
}
