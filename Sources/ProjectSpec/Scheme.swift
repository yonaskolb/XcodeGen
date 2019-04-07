import Foundation
import JSONUtilities
import xcodeproj

public typealias BuildType = XCScheme.BuildAction.Entry.BuildFor

public struct Scheme: Equatable {

    public var name: String
    public var build: Build
    public var run: Run?
    public var archive: Archive?
    public var analyze: Analyze?
    public var test: Test?
    public var profile: Profile?

    public init(
        name: String,
        build: Build,
        run: Run? = nil,
        test: Test? = nil,
        profile: Profile? = nil,
        analyze: Analyze? = nil,
        archive: Archive? = nil
    ) {
        self.name = name
        self.build = build
        self.run = run
        self.test = test
        self.profile = profile
        self.analyze = analyze
        self.archive = archive
    }

    public struct ExecutionAction: Equatable {
        public var script: String
        public var name: String
        public var settingsTarget: String?
        public init(name: String, script: String, settingsTarget: String? = nil) {
            self.script = script
            self.name = name
            self.settingsTarget = settingsTarget
        }
    }

    public struct Build: Equatable {
        public var targets: [BuildTarget]
        public var parallelizeBuild: Bool
        public var buildImplicitDependencies: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            targets: [BuildTarget],
            parallelizeBuild: Bool = true,
            buildImplicitDependencies: Bool = true,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.targets = targets
            self.parallelizeBuild = parallelizeBuild
            self.buildImplicitDependencies = buildImplicitDependencies
            self.preActions = preActions
            self.postActions = postActions
        }
    }

    public struct Run: BuildAction {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }
    }

    public struct Test: BuildAction {
        public var config: String?
        public var gatherCoverageData: Bool
        public var commandLineArguments: [String: Bool]
        public var targets: [TestTarget]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]

        public struct TestTarget: Equatable, ExpressibleByStringLiteral {
            public let name: String
            public var randomExecutionOrder: Bool
            public var parallelizable: Bool

            public init(
                name: String,
                randomExecutionOrder: Bool = false,
                parallelizable: Bool = false
            ) {
                self.name = name
                self.randomExecutionOrder = randomExecutionOrder
                self.parallelizable = parallelizable
            }

            public init(stringLiteral value: String) {
                name = value
                randomExecutionOrder = false
                parallelizable = false
            }
        }

        public init(
            config: String,
            gatherCoverageData: Bool = false,
            randomExecutionOrder: Bool = false,
            parallelizable: Bool = false,
            commandLineArguments: [String: Bool] = [:],
            targets: [TestTarget] = [],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
            self.commandLineArguments = commandLineArguments
            self.targets = targets
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            return commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }

    public struct Analyze: BuildAction {
        public var config: String?
        public init(config: String) {
            self.config = config
        }
    }

    public struct Profile: BuildAction {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = []
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            return commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }

    public struct Archive: BuildAction {
        public var config: String?
        public var customArchiveName: String?
        public var revealArchiveInOrganizer: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            config: String,
            customArchiveName: String? = nil,
            revealArchiveInOrganizer: Bool = true,
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = []
        ) {
            self.config = config
            self.customArchiveName = customArchiveName
            self.revealArchiveInOrganizer = revealArchiveInOrganizer
            self.preActions = preActions
            self.postActions = postActions
        }
    }

    public struct BuildTarget: Equatable {
        public var target: String
        public var buildTypes: [BuildType]

        public init(target: String, buildTypes: [BuildType] = BuildType.all) {
            self.target = target
            self.buildTypes = buildTypes
        }
    }
}

protocol BuildAction: Equatable {
    var config: String? { get }
}

extension Scheme.ExecutionAction: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        script = try jsonDictionary.json(atKeyPath: "script")
        name = jsonDictionary.json(atKeyPath: "name") ?? "Run Script"
        settingsTarget = jsonDictionary.json(atKeyPath: "settingsTarget")
    }
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        if let targets = jsonDictionary["targets"] as? [Any] {
            self.targets = try targets.compactMap { target in
                if let string = target as? String {
                    return TestTarget(name: string)
                } else if let dictionary = target as? JSONDictionary {
                    return try TestTarget(jsonDictionary: dictionary)
                } else {
                    return nil
                }
            }
        } else {
            targets = []
        }
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Test.TestTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        randomExecutionOrder = jsonDictionary.json(atKeyPath: "randomExecutionOrder") ?? false
        parallelizable = jsonDictionary.json(atKeyPath: "parallelizable") ?? false
    }
}

extension Scheme.Profile: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
    }
}

extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        customArchiveName = jsonDictionary.json(atKeyPath: "customArchiveName")
        revealArchiveInOrganizer = jsonDictionary.json(atKeyPath: "revealArchiveInOrganizer") ?? true
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
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
                buildTypes = enabledDictionary.filter { $0.value }.compactMap { BuildType.from(jsonValue: $0.key) }
            } else if let array = possibleBuildTypes as? [String] {
                buildTypes = array.compactMap(BuildType.from)
            } else {
                buildTypes = BuildType.all
            }
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target < $1.target }
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        parallelizeBuild = jsonDictionary.json(atKeyPath: "parallelizeBuild") ?? true
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? true
    }
}

extension BuildType: JSONPrimitiveConvertible {

    public typealias JSONType = String

    public static func from(jsonValue: String) -> BuildType? {
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

extension XCScheme.EnvironmentVariable: JSONObjectConvertible {

    private static func parseValue(_ value: Any) -> String {
        if let bool = value as? Bool {
            return bool ? "YES" : "NO"
        } else {
            return String(describing: value)
        }
    }

    public init(jsonDictionary: JSONDictionary) throws {

        let value: String
        if let jsonValue = jsonDictionary["value"] {
            value = XCScheme.EnvironmentVariable.parseValue(jsonValue)
        } else {
            // will throw error
            value = try jsonDictionary.json(atKeyPath: "value")
        }
        let variable: String = try jsonDictionary.json(atKeyPath: "variable")
        let enabled: Bool = jsonDictionary.json(atKeyPath: "isEnabled") ?? true
        self.init(variable: variable, value: value, enabled: enabled)
    }

    static func parseAll(jsonDictionary: JSONDictionary) throws -> [XCScheme.EnvironmentVariable] {
        if let variablesDictionary: [String: Any] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return variablesDictionary.mapValues(parseValue)
                .map { XCScheme.EnvironmentVariable(variable: $0.key, value: $0.value, enabled: true) }
                .sorted { $0.variable < $1.variable }
        } else if let variablesArray: [JSONDictionary] = jsonDictionary.json(atKeyPath: "environmentVariables") {
            return try variablesArray.map(XCScheme.EnvironmentVariable.init)
        } else {
            return []
        }
    }
}
