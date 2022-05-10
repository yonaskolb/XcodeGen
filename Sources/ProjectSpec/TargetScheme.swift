import Foundation
import JSONUtilities
import XcodeProj

public struct TargetScheme: Equatable {
    public static let gatherCoverageDataDefault = false
    public static let disableMainThreadCheckerDefault = false
    public static let stopOnEveryMainThreadCheckerIssueDefault = false
    public static let buildImplicitDependenciesDefault = true

    public var testTargets: [Scheme.Test.TestTarget]
    public var configVariants: [String]
    public var gatherCoverageData: Bool
    public var coverageTargets: [TestableTargetReference]
    public var storeKitConfiguration: String?
    public var language: String?
    public var region: String?
    public var disableMainThreadChecker: Bool
    public var stopOnEveryMainThreadCheckerIssue: Bool
    public var buildImplicitDependencies: Bool
    public var commandLineArguments: [String: Bool]
    public var environmentVariables: [XCScheme.EnvironmentVariable]
    public var preActions: [Scheme.ExecutionAction]
    public var postActions: [Scheme.ExecutionAction]
    public var testPlans: [TestPlan]

    public init(
        testTargets: [Scheme.Test.TestTarget] = [],
        testPlans: [TestPlan] = [],
        configVariants: [String] = [],
        gatherCoverageData: Bool = gatherCoverageDataDefault,
        coverageTargets: [TestableTargetReference] = [],
        storeKitConfiguration: String? = nil,
        language: String? = nil,
        region: String? = nil,
        disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
        stopOnEveryMainThreadCheckerIssue: Bool = stopOnEveryMainThreadCheckerIssueDefault,
        buildImplicitDependencies: Bool = buildImplicitDependenciesDefault,
        commandLineArguments: [String: Bool] = [:],
        environmentVariables: [XCScheme.EnvironmentVariable] = [],
        preActions: [Scheme.ExecutionAction] = [],
        postActions: [Scheme.ExecutionAction] = []
    ) {
        self.testTargets = testTargets
        self.testPlans = testPlans
        self.configVariants = configVariants
        self.gatherCoverageData = gatherCoverageData
        self.coverageTargets = coverageTargets
        self.storeKitConfiguration = storeKitConfiguration
        self.language = language
        self.region = region
        self.disableMainThreadChecker = disableMainThreadChecker
        self.stopOnEveryMainThreadCheckerIssue = stopOnEveryMainThreadCheckerIssue
        self.buildImplicitDependencies = buildImplicitDependencies
        self.commandLineArguments = commandLineArguments
        self.environmentVariables = environmentVariables
        self.preActions = preActions
        self.postActions = postActions
    }
}

extension TargetScheme: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let targets = jsonDictionary["testTargets"] as? [Any] {
            testTargets = try targets.compactMap { target in
                if let string = target as? String {
                    return .init(targetReference: try TestableTargetReference(string))
                } else if let dictionary = target as? JSONDictionary,
                          let target: Scheme.Test.TestTarget = try? .init(jsonDictionary: dictionary) {
                    return target
                } else {
                    return nil
                }
            }
        } else {
            testTargets = []
        }

        if let targets = jsonDictionary["coverageTargets"] as? [Any] {
            coverageTargets = try targets.compactMap { target in
                if let string = target as? String {
                    return try TestableTargetReference(string)
                } else if let dictionary = target as? JSONDictionary,
                          let target: TestableTargetReference = try? .init(jsonDictionary: dictionary) {
                    return target
                } else {
                    return nil
                }
            }
        } else {
            coverageTargets = []
        }

        testPlans = try (jsonDictionary.json(atKeyPath: "testPlans") ?? []).map { try TestPlan(jsonDictionary: $0) }
        configVariants = jsonDictionary.json(atKeyPath: "configVariants") ?? []
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? TargetScheme.gatherCoverageDataDefault
        storeKitConfiguration = jsonDictionary.json(atKeyPath: "storeKitConfiguration")
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? TargetScheme.disableMainThreadCheckerDefault
        stopOnEveryMainThreadCheckerIssue = jsonDictionary.json(atKeyPath: "stopOnEveryMainThreadCheckerIssue") ?? TargetScheme.stopOnEveryMainThreadCheckerIssueDefault
        buildImplicitDependencies = jsonDictionary.json(atKeyPath: "buildImplicitDependencies") ?? TargetScheme.buildImplicitDependenciesDefault
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
    }
}

extension TargetScheme: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any] = [
            "configVariants": configVariants,
            "coverageTargets": coverageTargets.map { $0.reference },
            "commandLineArguments": commandLineArguments,
            "testTargets": testTargets.map { $0.toJSONValue() },
            "testPlans": testPlans.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
        ]

        if gatherCoverageData != TargetScheme.gatherCoverageDataDefault {
            dict["gatherCoverageData"] = gatherCoverageData
        }

        if let storeKitConfiguration = storeKitConfiguration {
            dict["storeKitConfiguration"] = storeKitConfiguration
        }

        if disableMainThreadChecker != TargetScheme.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if stopOnEveryMainThreadCheckerIssue != TargetScheme.stopOnEveryMainThreadCheckerIssueDefault {
            dict["stopOnEveryMainThreadCheckerIssue"] = stopOnEveryMainThreadCheckerIssue
        }

        if buildImplicitDependencies != TargetScheme.buildImplicitDependenciesDefault {
            dict["buildImplicitDependencies"] = buildImplicitDependencies
        }

        if let language = language {
            dict["language"] = language
        }

        if let region = region {
            dict["region"] = region
        }

        return dict
    }
}

extension TargetScheme: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .object("testPlans", TestPlan.pathProperties),
        ]
    }
}
