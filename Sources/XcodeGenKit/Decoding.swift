//
//  Decoding.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/5/17.
//
//

import Foundation
import JSONUtilities

extension Dictionary where Key: JSONKey {

    public func json<T: NamedJSONObjectConvertible>(atKeyPath keyPath: KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        guard let dictionary = json(atKeyPath: keyPath) as JSONDictionary? else {
            return []
        }
        var items: [T] = []
        for (key, _) in dictionary {
            let jsonDictionary: JSONDictionary = try dictionary.json(atKeyPath: .key(key))
            let item = try T(name: key, jsonDictionary: jsonDictionary)
            items.append(item)
        }
        return items
    }
}

public protocol NamedJSONObjectConvertible {

    init(name: String, jsonDictionary: JSONDictionary) throws
}
