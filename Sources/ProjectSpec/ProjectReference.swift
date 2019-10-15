//
//  ProjectReference.swift
//  ProjectSpec
//
//  Created by Yuta Saito on 2019/10/15.
//

import Foundation
import JSONUtilities

public struct ProjectReference {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

extension ProjectReference: NamedJSONDictionaryConvertible {
    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        self.path = try jsonDictionary.json(atKeyPath: "path")
    }
}

extension ProjectReference: JSONEncodable {
    public func toJSONValue() -> Any {
        return [
            "path": path,
        ]
    }
}
