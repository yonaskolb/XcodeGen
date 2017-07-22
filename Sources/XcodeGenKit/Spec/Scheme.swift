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

    public init(name: String, build: Build) {
        self.name = name
        self.build = build
    }

    public struct Build {
        public var entries: [BuildEntry]
        public init(entries: [BuildEntry]) {
            self.entries = entries
        }
    }

    public struct BuildEntry {
        public var target: String
        public var buildTypes: [XCScheme.BuildAction.Entry.BuildFor]

        public init(target: String, buildTypes: [XCScheme.BuildAction.Entry.BuildFor] = XCScheme.BuildAction.Entry.BuildFor.default) {
            self.target = target
            self.buildTypes = buildTypes
        }
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
        buildTypes = jsonDictionary.json(atKeyPath: "buildTypes") ?? XCScheme.BuildAction.Entry.BuildFor.default
    }
}

extension XCScheme.BuildAction.Entry.BuildFor: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> XCScheme.BuildAction.Entry.BuildFor? {
        return .testing
    }
}
