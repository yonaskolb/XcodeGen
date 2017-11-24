import Foundation
import xcproj
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

    public init(name: String, targets: [BuildTarget], debugConfig: String, releaseConfig: String, gatherCoverageData: Bool = false) {
        self.init(name: name,
                  build: .init(targets: targets),
                  run: .init(config: debugConfig),
                  test: .init(config: debugConfig, gatherCoverageData: gatherCoverageData),
                  profile: .init(config: releaseConfig),
                  analyze: .init(config: debugConfig),
                  archive: .init(config: releaseConfig))
    }

    public struct Build: Equatable {
        public var targets: [BuildTarget]
        public init(targets: [BuildTarget]) {
            self.targets = targets
        }

        public static func == (lhs: Build, rhs: Build) -> Bool {
            return lhs.targets == rhs.targets
        }
    }

    public struct Run: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }

        public static func == (lhs: Run, rhs: Run) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct Test: BuildAction {
        public var config: String
        public var gatherCoverageData: Bool
        public init(config: String, gatherCoverageData: Bool = false) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
        }

        public static func == (lhs: Test, rhs: Test) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct Analyze: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }

        public static func == (lhs: Analyze, rhs: Analyze) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct Profile: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }

        public static func == (lhs: Profile, rhs: Profile) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct Archive: BuildAction {
        public var config: String
        public init(config: String) {
            self.config = config
        }

        public static func == (lhs: Archive, rhs: Archive) -> Bool {
            return lhs.config == rhs.config
        }
    }

    public struct BuildTarget: Equatable {
        public var target: String
        public var buildTypes: [BuildType]

        public init(target: String, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }

        public static func == (lhs: BuildTarget, rhs: BuildTarget) -> Bool {
            return lhs.target == rhs.target && lhs.buildTypes == rhs.buildTypes
        }
    }

    public static func == (lhs: Scheme, rhs: Scheme) -> Bool {
        return lhs.build == rhs.build &&
            lhs.run == rhs.run &&
            lhs.test == rhs.test &&
            lhs.analyze == rhs.analyze &&
            lhs.profile == rhs.profile &&
            lhs.archive == rhs.archive
    }
}

protocol BuildAction: Equatable {
    var config: String { get }
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
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
