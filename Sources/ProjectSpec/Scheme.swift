import Foundation
import JSONUtilities
import XcodeProj

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

    public struct SimulateLocation: Equatable {
        public enum ReferenceType: String {
            case predefined = "1"
            case gpx = "0"
        }

        public var allow: Bool
        public var defaultLocation: String?

        public var referenceType: ReferenceType? {
            guard let defaultLocation = self.defaultLocation else {
                return nil
            }

            if defaultLocation.contains(".gpx") {
                return .gpx
            }
            return .predefined
        }

        public init(allow: Bool, defaultLocation: String) {
            self.allow = allow
            self.defaultLocation = defaultLocation
        }
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
        public static let parallelizeBuildDefault = true
        public static let buildImplicitDependenciesDefault = true

        public var targets: [BuildTarget]
        public var parallelizeBuild: Bool
        public var buildImplicitDependencies: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]

        public init(
            targets: [BuildTarget],
            parallelizeBuild: Bool = parallelizeBuildDefault,
            buildImplicitDependencies: Bool = buildImplicitDependenciesDefault,
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
        public static let disableMainThreadCheckerDefault = false
        public static let stopOnEveryMainThreadCheckerIssueDefault = false
        public static let debugEnabledDefault = true

        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var disableMainThreadChecker: Bool
        public var stopOnEveryMainThreadCheckerIssue: Bool
        public var language: String?
        public var region: String?
        public var askForAppToLaunch: Bool?
        public var launchAutomaticallySubstyle: String?
        public var debugEnabled: Bool
        public var simulateLocation: SimulateLocation?
        public var executable: String?
        public var customLLDBInit: String?

        public init(
            config: String,
            executable: String? = nil,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
            stopOnEveryMainThreadCheckerIssue: Bool = stopOnEveryMainThreadCheckerIssueDefault,
            language: String? = nil,
            region: String? = nil,
            askForAppToLaunch: Bool? = nil,
            launchAutomaticallySubstyle: String? = nil,
            debugEnabled: Bool = debugEnabledDefault,
            simulateLocation: SimulateLocation? = nil,
            customLLDBInit: String? = nil
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.disableMainThreadChecker = disableMainThreadChecker
            self.stopOnEveryMainThreadCheckerIssue = stopOnEveryMainThreadCheckerIssue
            self.language = language
            self.region = region
            self.askForAppToLaunch = askForAppToLaunch
            self.launchAutomaticallySubstyle = launchAutomaticallySubstyle
            self.debugEnabled = debugEnabled
            self.simulateLocation = simulateLocation
            self.customLLDBInit = customLLDBInit
        }
    }

    public struct Test: BuildAction {
        public static let gatherCoverageDataDefault = false
        public static let disableMainThreadCheckerDefault = false
        public static let debugEnabledDefault = true

        public var config: String?
        public var gatherCoverageData: Bool
        public var coverageTargets: [TargetReference]
        public var disableMainThreadChecker: Bool
        public var commandLineArguments: [String: Bool]
        public var targets: [TestTarget]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var language: String?
        public var region: String?
        public var debugEnabled: Bool
        public var customLLDBInit: String?

        public struct TestTarget: Equatable, ExpressibleByStringLiteral {
            public static let randomExecutionOrderDefault = false
            public static let parallelizableDefault = false

            public var name: String { targetReference.name }
            public let targetReference: TargetReference
            public var randomExecutionOrder: Bool
            public var parallelizable: Bool
            public var skipped: Bool
            public var skippedTests: [String]

            public init(
                targetReference: TargetReference,
                randomExecutionOrder: Bool = randomExecutionOrderDefault,
                parallelizable: Bool = parallelizableDefault,
                skipped: Bool = false,
                skippedTests: [String] = []
            ) {
                self.targetReference = targetReference
                self.randomExecutionOrder = randomExecutionOrder
                self.parallelizable = parallelizable
                self.skipped = skipped
                self.skippedTests = skippedTests
            }

            public init(stringLiteral value: String) {
                do {
                    targetReference = try TargetReference(value)
                    randomExecutionOrder = false
                    parallelizable = false
                    skipped = false
                    skippedTests = []
                } catch {
                    fatalError(SpecParsingError.invalidTargetReference(value).description)
                }
            }
        }

        public init(
            config: String,
            gatherCoverageData: Bool = gatherCoverageDataDefault,
            coverageTargets: [TargetReference] = [],
            disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
            randomExecutionOrder: Bool = false,
            parallelizable: Bool = false,
            commandLineArguments: [String: Bool] = [:],
            targets: [TestTarget] = [],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            language: String? = nil,
            region: String? = nil,
            debugEnabled: Bool = debugEnabledDefault,
            customLLDBInit: String? = nil
        ) {
            self.config = config
            self.gatherCoverageData = gatherCoverageData
            self.coverageTargets = coverageTargets
            self.disableMainThreadChecker = disableMainThreadChecker
            self.commandLineArguments = commandLineArguments
            self.targets = targets
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.language = language
            self.region = region
            self.debugEnabled = debugEnabled
            self.customLLDBInit = customLLDBInit
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            commandLineArguments.isEmpty && environmentVariables.isEmpty
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
            commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }

    public struct Archive: BuildAction {
        public static let revealArchiveInOrganizerDefault = true

        public var config: String?
        public var customArchiveName: String?
        public var revealArchiveInOrganizer: Bool
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public init(
            config: String,
            customArchiveName: String? = nil,
            revealArchiveInOrganizer: Bool = revealArchiveInOrganizerDefault,
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

    public struct BuildTarget: Equatable, Hashable {
        public var target: TargetReference
        public var buildTypes: [BuildType]

        public init(target: TargetReference, buildTypes: [BuildType] = BuildType.all) {
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

extension Scheme.ExecutionAction: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "script": script,
            "name": name,
            "settingsTarget": settingsTarget,
        ]
    }
}

extension Scheme.SimulateLocation: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        allow = try jsonDictionary.json(atKeyPath: "allow")
        defaultLocation = jsonDictionary.json(atKeyPath: "defaultLocation")
    }
}

extension Scheme.SimulateLocation: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any] = [
            "allow": allow,
        ]

        if let defaultLocation = defaultLocation {
            dict["defaultLocation"] = defaultLocation
        }

        return dict
    }
}

extension Scheme.Run: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? Scheme.Run.disableMainThreadCheckerDefault
        stopOnEveryMainThreadCheckerIssue = jsonDictionary.json(atKeyPath: "stopOnEveryMainThreadCheckerIssue") ?? Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Run.debugEnabledDefault
        simulateLocation = jsonDictionary.json(atKeyPath: "simulateLocation")
        executable = jsonDictionary.json(atKeyPath: "executable")

        // launchAutomaticallySubstyle is defined as a String in XcodeProj but its value is often
        // an integer. Parse both to be nice.
        if let int: Int = jsonDictionary.json(atKeyPath: "launchAutomaticallySubstyle") {
            launchAutomaticallySubstyle = String(int)
        } else if let string: String = jsonDictionary.json(atKeyPath: "launchAutomaticallySubstyle") {
            launchAutomaticallySubstyle = string
        }

        if let askLaunch: Bool = jsonDictionary.json(atKeyPath: "askForAppToLaunch") {
            askForAppToLaunch = askLaunch
        }
        customLLDBInit = jsonDictionary.json(atKeyPath: "customLLDBInit")
    }
}

extension Scheme.Run: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "commandLineArguments": commandLineArguments,
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "config": config,
            "language": language,
            "region": region,
            "askForAppToLaunch": askForAppToLaunch,
            "launchAutomaticallySubstyle": launchAutomaticallySubstyle,
            "executable": executable,
        ]

        if disableMainThreadChecker != Scheme.Run.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if stopOnEveryMainThreadCheckerIssue != Scheme.Run.stopOnEveryMainThreadCheckerIssueDefault {
            dict["stopOnEveryMainThreadCheckerIssue"] = stopOnEveryMainThreadCheckerIssue
        }

        if debugEnabled != Scheme.Run.debugEnabledDefault {
            dict["debugEnabled"] = debugEnabled
        }

        if let simulateLocation = simulateLocation {
            dict["simulateLocation"] = simulateLocation.toJSONValue()
        }
        if let customLLDBInit = customLLDBInit {
            dict["customLLDBInit"] = customLLDBInit
        }
        return dict
    }
}

extension Scheme.Test: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? Scheme.Test.gatherCoverageDataDefault
        coverageTargets = try (jsonDictionary.json(atKeyPath: "coverageTargets") ?? []).map { try TargetReference($0) }
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? Scheme.Test.disableMainThreadCheckerDefault
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        if let targets = jsonDictionary["targets"] as? [Any] {
            self.targets = try targets.compactMap { target in
                if let string = target as? String {
                    return try TestTarget(targetReference: TargetReference(string))
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
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Test.debugEnabledDefault
        customLLDBInit = jsonDictionary.json(atKeyPath: "customLLDBInit")
    }
}

extension Scheme.Test: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "commandLineArguments": commandLineArguments,
            "targets": targets.map { $0.toJSONValue() },
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "config": config,
            "language": language,
            "region": region,
            "coverageTargets": coverageTargets.map { $0.reference },
        ]

        if gatherCoverageData != Scheme.Test.gatherCoverageDataDefault {
            dict["gatherCoverageData"] = gatherCoverageData
        }

        if disableMainThreadChecker != Scheme.Test.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if debugEnabled != Scheme.Run.debugEnabledDefault {
            dict["debugEnabled"] = debugEnabled
        }

        if let customLLDBInit = customLLDBInit {
            dict["customLLDBInit"] = customLLDBInit
        }

        return dict
    }
}

extension Scheme.Test.TestTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        targetReference = try TargetReference(jsonDictionary.json(atKeyPath: "name"))
        randomExecutionOrder = jsonDictionary.json(atKeyPath: "randomExecutionOrder") ?? Scheme.Test.TestTarget.randomExecutionOrderDefault
        parallelizable = jsonDictionary.json(atKeyPath: "parallelizable") ?? Scheme.Test.TestTarget.parallelizableDefault
        skipped = jsonDictionary.json(atKeyPath: "skipped") ?? false
        skippedTests = jsonDictionary.json(atKeyPath: "skippedTests") ?? []
    }
}

extension Scheme.Test.TestTarget: JSONEncodable {
    public func toJSONValue() -> Any {
        if randomExecutionOrder == Scheme.Test.TestTarget.randomExecutionOrderDefault,
            parallelizable == Scheme.Test.TestTarget.parallelizableDefault {
            return targetReference.reference
        }

        var dict: JSONDictionary = [
            "name": targetReference.reference,
        ]

        if randomExecutionOrder != Scheme.Test.TestTarget.randomExecutionOrderDefault {
            dict["randomExecutionOrder"] = randomExecutionOrder
        }
        if parallelizable != Scheme.Test.TestTarget.parallelizableDefault {
            dict["parallelizable"] = parallelizable
        }
        if skipped {
            dict["skipped"] = skipped
        }

        return dict
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

extension Scheme.Profile: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "commandLineArguments": commandLineArguments,
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "config": config,
        ] as [String: Any?]
    }
}

extension Scheme.Analyze: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
    }
}

extension Scheme.Analyze: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "config": config,
        ]
    }
}

extension Scheme.Archive: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        config = jsonDictionary.json(atKeyPath: "config")
        customArchiveName = jsonDictionary.json(atKeyPath: "customArchiveName")
        revealArchiveInOrganizer = jsonDictionary.json(atKeyPath: "revealArchiveInOrganizer") ?? Scheme.Archive.revealArchiveInOrganizerDefault
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
    }
}

extension Scheme.Archive: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
            "config": config,
            "customArchiveName": customArchiveName,
        ]

        if revealArchiveInOrganizer != Scheme.Archive.revealArchiveInOrganizerDefault {
            dict["revealArchiveInOrganizer"] = revealArchiveInOrganizer
        }

        return dict
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

extension Scheme: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "build": build.toJSONValue(),
            "run": run?.toJSONValue(),
            "test": test?.toJSONValue(),
            "analyze": analyze?.toJSONValue(),
            "profile": profile?.toJSONValue(),
            "archive": archive?.toJSONValue(),
        ] as [String: Any?]
    }
}

extension Scheme.Build: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let targetDictionary: JSONDictionary = try jsonDictionary.json(atKeyPath: "targets")
        var targets: [Scheme.BuildTarget] = []
        for (targetRepr, possibleBuildTypes) in targetDictionary {
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
            let target = try TargetReference(targetRepr)
            targets.append(Scheme.BuildTarget(target: target, buildTypes: buildTypes))
        }
        self.targets = targets.sorted { $0.target.name < $1.target.name }
        preActions = try jsonDictionary.json(atKeyPath: "preActions")?.map(Scheme.ExecutionAction.init) ?? []
        postActions = try jsonDictionary.json(atKeyPath: "postActions")?.map(Scheme.ExecutionAction.init) ?? []
        parallelizeBuild = jsonDictionary.json(atKeyPath: "parallelizeBuild") ?? Scheme.Build.parallelizeBuildDefault
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? Scheme.Build.buildImplicitDependenciesDefault
    }
}

extension Scheme.Build: JSONEncodable {
    public func toJSONValue() -> Any {
        let targetPairs = targets.map { ($0.target.reference, $0.buildTypes.map { $0.toJSONValue() }) }

        var dict: JSONDictionary = [
            "targets": Dictionary(uniqueKeysWithValues: targetPairs),
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
        ]

        if parallelizeBuild != Scheme.Build.parallelizeBuildDefault {
            dict["parallelizeBuild"] = parallelizeBuild
        }
        if buildImplicitDependencies != Scheme.Build.buildImplicitDependenciesDefault {
            dict["buildImplicitDependencies"] = buildImplicitDependencies
        }

        return dict
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
        [.running, .testing, .profiling, .analyzing, .archiving]
    }
}

extension BuildType: JSONEncodable {
    public func toJSONValue() -> Any {
        switch self {
        case .testing: return "testing"
        case .profiling: return "profiling"
        case .running: return "running"
        case .archiving: return "archiving"
        case .analyzing: return "analyzing"
        }
    }
}

extension XCScheme.EnvironmentVariable: JSONObjectConvertible {
    public static let enabledDefault = true

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
        let enabled: Bool = jsonDictionary.json(atKeyPath: "isEnabled") ?? XCScheme.EnvironmentVariable.enabledDefault
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

extension XCScheme.EnvironmentVariable: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any] = [
            "variable": variable,
            "value": value,
        ]

        if enabled != XCScheme.EnvironmentVariable.enabledDefault {
            dict["isEnabled"] = enabled
        }

        return dict
    }
}
