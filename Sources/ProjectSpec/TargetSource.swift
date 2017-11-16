//
//  Source.swift
//  ProjectSpec
//
//  Created by Yonas Kolb on 31/10/17.
//

import Foundation
import JSONUtilities
import PathKit

public struct TargetSource {

    public var path: String
    public var name: String?
    public var compilerFlags: [String]
    public var excludes: [String]
    public var type: SourceType?

    public enum SourceType: String {
        case group
        case file
        case folder
    }

    public init(path: String, name: String? = nil, compilerFlags: [String] = [], excludes: [String] = [], type: SourceType? = nil) {
        self.path = path
        self.name = name
        self.compilerFlags = compilerFlags
        self.excludes = excludes
        self.type = type
    }
}

extension TargetSource: ExpressibleByStringLiteral {

    public init(stringLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = TargetSource(path: value)
    }

    public init(unicodeScalarLiteral value: String) {
        self = TargetSource(path: value)
    }
}

extension TargetSource: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        name = jsonDictionary.json(atKeyPath: "name")

        let maybeCompilerFlagsString: String? = jsonDictionary.json(atKeyPath: "compilerFlags")
        let maybeCompilerFlagsArray: [String]? = jsonDictionary.json(atKeyPath: "compilerFlags")
        compilerFlags = maybeCompilerFlagsArray ??
            maybeCompilerFlagsString.map { $0.split(separator: " ").map { String($0) } } ?? []

        excludes = jsonDictionary.json(atKeyPath: "excludes") ?? []
        type = jsonDictionary.json(atKeyPath: "type")
    }
}

extension TargetSource: Equatable {

    public static func == (lhs: TargetSource, rhs: TargetSource) -> Bool {
        return lhs.path == rhs.path
            && lhs.name == rhs.name
            && lhs.compilerFlags == rhs.compilerFlags
            && lhs.excludes == rhs.excludes
            && lhs.type == rhs.type
    }
}
