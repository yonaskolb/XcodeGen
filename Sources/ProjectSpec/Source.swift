//
//  Source.swift
//  ProjectSpec
//
//  Created by Yonas Kolb on 31/10/17.
//

import Foundation
import JSONUtilities
import PathKit

public struct Source {

    public var path: String
    public var compilerFlags: [String]
    public var excludes: [String]

    public init(path: String, compilerFlags: [String] = [], excludes: [String] = []) {
        self.path = path
        self.compilerFlags = compilerFlags
        self.excludes = excludes
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

        let maybeCompilerFlagsString: String? = jsonDictionary.json(atKeyPath: "compilerFlags")
        let maybeCompilerFlagsArray: [String]? = jsonDictionary.json(atKeyPath: "compilerFlags")
        compilerFlags = maybeCompilerFlagsArray ??
            maybeCompilerFlagsString.map{ $0.split(separator: " ").map{ String($0) } } ?? []

        excludes = jsonDictionary.json(atKeyPath: "excludes") ?? []
    }
}

extension Source: Equatable {

    public static func == (lhs: Source, rhs: Source) -> Bool {
        return lhs.path == rhs.path 
            && lhs.compilerFlags == rhs.compilerFlags
            && lhs.excludes == rhs.excludes
    }
}

extension Source: Hashable {
    public var hashValue: Int {
        return path.hashValue 
            ^ compilerFlags.joined(separator: ":").hashValue
            ^ excludes.joined(separator: ":").hashValue
    }
}
