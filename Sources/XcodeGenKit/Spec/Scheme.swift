//
//  Scheme.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/5/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct Scheme {

    public var name: String
    public var build: Build

    public struct Build {
        public var entries: [BuildEntry]
    }

    public struct BuildEntry {
        public var target: String
        public var buildTypes: [XCScheme.BuildAction.Entry.BuildFor]
    }
}

extension Scheme: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        build = try jsonDictionary.json(atKeyPath: "build")
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        entries = try jsonDictionary.json(atKeyPath: "targets")
    }
}

extension Scheme.BuildEntry: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        target = name
        buildTypes = jsonDictionary.json(atKeyPath: "buildTypes") ?? [.running, .testing, .archiving, .analyzing]
    }
}

extension XCScheme.BuildAction.Entry.BuildFor: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> XCScheme.BuildAction.Entry.BuildFor? {
        return .testing
    }
}
