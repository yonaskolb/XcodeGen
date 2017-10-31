//
//  Source.swift
//  ProjectSpec
//
//  Created by Yonas Kolb on 31/10/17.
//

import Foundation
import JSONUtilities

public struct Source {

    public var path: String

    public init(path: String) {
        self.path = path
    }
}

extension Source: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = Source(path: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = Source(path: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self = Source(path: value)
    }
}

extension Source: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
    }
}

extension Source: Equatable {

    public static func == (lhs: Source, rhs: Source) -> Bool {
        return lhs.path == rhs.path
    }
}
