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

public typealias BuildType = XCScheme.BuildAction.Entry.BuildFor

public struct Scheme: Equatable {

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

    public init(name: String, targets: [BuildTarget], debugConfiguration: String, releaseConfiguration: String) {
        self.init(name: name,
                  build: .init(targets: targets),
                  run: .init(configuration: debugConfiguration),
                  test: .init(configuration: debugConfiguration),
                  profile: .init(configuration: releaseConfiguration),
                  analyze: .init(configuration: debugConfiguration),
                  archive: .init(configuration: releaseConfiguration))
    }

    public struct Build: Equatable {
        public var targets: [BuildTarget]
        public init(targets: [BuildTarget]) {
            self.targets = targets
        }

        public static func ==(lhs: Build, rhs: Build) -> Bool {
            return lhs.targets == rhs.targets
        }
    }

    public struct Run: BuildAction {
        public var configuration: String
        public init(configuration: String) {
            self.configuration = configuration
        }

        public static func ==(lhs: Run, rhs: Run) -> Bool {
            return lhs.configuration == rhs.configuration
        }
    }

    public struct Test: BuildAction {
        public var configuration: String
        public init(configuration: String) {
            self.configuration = configuration
        }

        public static func ==(lhs: Test, rhs: Test) -> Bool {
            return lhs.configuration == rhs.configuration
        }
    }

    public struct Analyze: BuildAction {
        public var configuration: String
        public init(configuration: String) {
            self.configuration = configuration
        }

        public static func ==(lhs: Analyze, rhs: Analyze) -> Bool {
            return lhs.configuration == rhs.configuration
        }
    }

    public struct Profile: BuildAction {
        public var configuration: String
        public init(configuration: String) {
            self.configuration = configuration
        }

        public static func ==(lhs: Profile, rhs: Profile) -> Bool {
            return lhs.configuration == rhs.configuration
        }
    }

    public struct Archive: BuildAction {
        public var configuration: String
        public init(configuration: String) {
            self.configuration = configuration
        }

        public static func ==(lhs: Archive, rhs: Archive) -> Bool {
            return lhs.configuration == rhs.configuration
        }
    }

    public struct BuildTarget: Equatable {
        public var target: String
        public var buildTypes: [BuildType]

        public init(target: String, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }

        public static func ==(lhs: BuildTarget, rhs: BuildTarget) -> Bool {
            return lhs.target == rhs.target && lhs.buildTypes == rhs.buildTypes
        }
    }

    public static func ==(lhs: Scheme, rhs: Scheme) -> Bool {
        return lhs.build == rhs.build &&
            lhs.run == rhs.run &&
            lhs.test == rhs.test &&
            lhs.analyze == rhs.analyze &&
            lhs.profile == rhs.profile &&
            lhs.archive == rhs.archive
    }
}

protocol BuildAction: Equatable {
    var configuration: String { get }

    init(configuration: String)
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        configuration = try jsonDictionary.json(atKeyPath: "configuration")
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        configuration = try jsonDictionary.json(atKeyPath: "configuration")
    }
}

extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        configuration = try jsonDictionary.json(atKeyPath: "configuration")
    }
}

extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        configuration = try jsonDictionary.json(atKeyPath: "configuration")
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        configuration = try jsonDictionary.json(atKeyPath: "configuration")
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
        targets = try jsonDictionary.json(atKeyPath: "targets")
    }
}

extension Scheme.BuildTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        target = try jsonDictionary.json(atKeyPath: "target")
        if jsonDictionary["buildTypes"] == nil {
            buildTypes = BuildType.all
        } else {
            if let types: String = jsonDictionary.json(atKeyPath: "buildTypes") {
                switch types {
                case "all": buildTypes = BuildType.all
                case "none": buildTypes = []
                case "testing": buildTypes = [.testing, .analyzing]
                case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                default: buildTypes = BuildType.all
                }
            } else {
                let types: [String: Bool] = try jsonDictionary.json(atKeyPath: "buildTypes")
                var buildTypes: [BuildType] = []
                for (type, build) in types {
                    if build, let buildType = BuildType.from(jsonValue: type) {
                        buildTypes.append(buildType)
                    }
                }
                self.buildTypes = buildTypes
            }
        }
    }
}

extension BuildType: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> XCScheme.BuildAction.Entry.BuildFor? {
        switch jsonValue {
        case "test", "testing": return .testing
        case "profile", "profiling": return .profiling
        case "run", "running": return .running
        case "archive", "archiving": return .archiving
        case "analyze", "analyzing": return .analyzing
        default: return nil
        }
    }

    public static var all: [BuildType] {
        return [.running, .testing, .profiling, .analyzing, .archiving]
    }
}
