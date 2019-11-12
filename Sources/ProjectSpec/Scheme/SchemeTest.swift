import Foundation
import JSONUtilities
import XcodeProj

extension Scheme {

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
        public var testPlans: [String]

        public struct TestTarget: Equatable, ExpressibleByStringLiteral {
            public static let randomExecutionOrderDefault = false
            public static let parallelizableDefault = false

            public var name: String { targetReference.name }
            public let targetReference: TargetReference
            public var randomExecutionOrder: Bool
            public var parallelizable: Bool
            public var skippedTests: [String]

            public init(
                targetReference: TargetReference,
                randomExecutionOrder: Bool = randomExecutionOrderDefault,
                parallelizable: Bool = parallelizableDefault,
                skippedTests: [String] = []
            ) {
                self.targetReference = targetReference
                self.randomExecutionOrder = randomExecutionOrder
                self.parallelizable = parallelizable
                self.skippedTests = skippedTests
            }

            public init(stringLiteral value: String) {
                do {
                    targetReference = try TargetReference(value)
                    randomExecutionOrder = false
                    parallelizable = false
                    skippedTests = []
                } catch {
                    fatalError(SpecParsingError.invalidTargetReference(value).description)
                }
            }
        }

        public init(
            config: String? = nil,
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
            testPlans: [String] = [],
            language: String? = nil,
            region: String? = nil,
            debugEnabled: Bool = debugEnabledDefault
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
            self.testPlans = testPlans
            self.language = language
            self.region = region
            self.debugEnabled = debugEnabled
        }

        public var shouldUseLaunchSchemeArgsEnv: Bool {
            commandLineArguments.isEmpty && environmentVariables.isEmpty
        }
    }
}

extension Scheme.Test: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("testPlans")
        ]
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
        testPlans = jsonDictionary.json(atKeyPath: "testPlans") ?? []
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Test.debugEnabledDefault
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
            "testPlans": testPlans,
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

        return dict
    }
}

extension Scheme.Test.TestTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        targetReference = try TargetReference(jsonDictionary.json(atKeyPath: "name"))
        randomExecutionOrder = jsonDictionary.json(atKeyPath: "randomExecutionOrder") ?? Scheme.Test.TestTarget.randomExecutionOrderDefault
        parallelizable = jsonDictionary.json(atKeyPath: "parallelizable") ?? Scheme.Test.TestTarget.parallelizableDefault
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

        return dict
    }
}
