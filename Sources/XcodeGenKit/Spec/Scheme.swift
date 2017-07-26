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
    public var run: Run?
    public var archive: Archive?
    public var analyze: Analyze?
    public var test: Test?
    public var profile: Profile?

    public init(name: String, build: Build, run: Run? = nil, test: Test? = nil, profile: Profile? = nil, analyze: Analyze? = nil, archive: Archive? = nil) {
        self.name = name
        self.build = build
        self.run = run
        self.test = test
        self.profile = profile
        self.analyze = analyze
        self.archive = archive
    }

    public init(name: String, targets: [BuildTarget], debugConfig: String, releaseConfig: String) {
        self.init(name: name,
                  build: .init(targets: targets),
                  run: .init(config: debugConfig),
                  test: .init(config: debugConfig),
                  profile: .init(config: releaseConfig),
                  analyze: .init(config: debugConfig),
                  archive: .init(config: releaseConfig))
    }

    public struct Build {
        public var targets: [BuildTarget]
        public init(targets: [BuildTarget]) {
            self.targets = targets
        }
    }

    public struct Run: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }
    }

    public struct Test: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }
    }

    public struct Analyze: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }
    }

    public struct Profile: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }
    }

    public struct Archive: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }
    }

    public struct BuildTarget {
        public var target: String
        public var buildTypes: [XCScheme.BuildAction.Entry.BuildFor]

        public init(target: String, buildTypes: [XCScheme.BuildAction.Entry.BuildFor] = XCScheme.BuildAction.Entry.BuildFor.default) {
            self.target = target
            self.buildTypes = buildTypes
        }
    }
}

protocol BuildAction {
    var config: String { get }

    init(config: String)
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}
extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}
extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}
extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}
extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        build = try jsonDictionary.json(atKeyPath: "build")
        run = jsonDictionary.json(atKeyPath: "run")
        test = jsonDictionary.json(atKeyPath: "test")
        analyze = jsonDictionary.json(atKeyPath: "analyze")
        profile = jsonDictionary.json(atKeyPath: "profile")
        archive = jsonDictionary.json(atKeyPath: "archive")
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {

        var targets: [Scheme.BuildTarget] = []
        let dictionary: [String: String] = try jsonDictionary.json(atKeyPath: "targets")

        for (key, value) in dictionary {
            let buildTypes: [XCScheme.BuildAction.Entry.BuildFor]
                switch value {
                    case "all": buildTypes = [.running, .testing, .profiling, .analyzing, .archiving]
                    case "none": buildTypes = []
                    case "testing": buildTypes = [.testing,.analyzing]
                    case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                    default: buildTypes = [.running, .testing, .profiling, .analyzing, .archiving]
                }
          targets.append(Scheme.BuildTarget(target: key, buildTypes: buildTypes))
        }

        self.targets = targets
    }
}

extension XCScheme.BuildAction.Entry.BuildFor: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> XCScheme.BuildAction.Entry.BuildFor? {
        switch jsonValue {
            case "test","testing": return .testing
            case "profile", "profiling": return .profiling
            case "run", "running": return .running
            case "archive", "archiving": return .archiving
            case "analyze", "analyzing": return .analyzing
        default: return nil
        }
    }
}
