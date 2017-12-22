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
        public var commandLineArguments: [String: Bool]
        public init(config: String, commandLineArguments: [String: Bool] = [:]) {
            self.config = config
            self.commandLineArguments = commandLineArguments
        }

        public static func == (lhs: Run, rhs: Run) -> Bool {
            return lhs.config == rhs.config &&
                lhs.commandLineArguments == rhs.commandLineArguments
        }
    }

    public struct Test: BuildAction {
        public var config: String
        public var gatherCoverageData: Bool
        public var commandLineArguments: [String: Bool]
        public var targets: [String]

        public init(config: String, gatherCoverageData: Bool = false, commandLineArguments: [String: Bool] = [:], targets: [String] = []) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
            self.commandLineArguments = commandLineArguments
            self.targets = targets
        }

        public static func == (lhs: Test, rhs: Test) -> Bool {
            return lhs.config == rhs.config &&
                lhs.commandLineArguments == rhs.commandLineArguments &&
                lhs.gatherCoverageData == rhs.gatherCoverageData &&
                lhs.targets == rhs.targets
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
        public var commandLineArguments: [String: Bool]
        public init(config: String, commandLineArguments: [String: Bool] = [:]) {
            self.config = config
            self.commandLineArguments = commandLineArguments
        }

        public static func == (lhs: Profile, rhs: Profile) -> Bool {
            return lhs.config == rhs.config && lhs.commandLineArguments == rhs.commandLineArguments
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
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        targets = jsonDictionary.json(atKeyPath: "targets") ?? []
    }
}

extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = try jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
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
        let targetDictionary: JSONDictionary = try jsonDictionary.json(atKeyPath: "targets")
        var targets: [Scheme.BuildTarget] = []
        for (target, possibleBuildTypes) in targetDictionary {
            let buildTypes: [BuildType]
            if let string = possibleBuildTypes as? String {
                switch string {
                case "all": buildTypes = BuildType.all
                case "none": buildTypes = []
                case "testing": buildTypes = [.testing, .analyzing]
                case "indexing": buildTypes = [.testing, .analyzing, .archiving]
                default: buildTypes = BuildType.all
                }
            } else if let enabledDictionary = possibleBuildTypes as? [String: Bool] {
                buildTypes = enabledDictionary.filter { $0.value }.flatMap { BuildType.from(jsonValue: $0.key) }
            } else if let array = possibleBuildTypes as? [String] {
                buildTypes = array.flatMap(BuildType.from)
            } else {
                buildTypes = BuildType.all
            }
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target < $1.target }
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
