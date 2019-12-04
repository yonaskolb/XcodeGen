import Foundation
import JSONUtilities
import XcodeProj

public struct TargetScheme: Equatable {
    public static let gatherCoverageDataDefault = false
    public static let disableMainThreadCheckerDefault = false

    public var testTargets: [Scheme.Test.TestTarget]
    public var configVariants: [String]
    public var gatherCoverageData: Bool
    public var language: String?
    public var region: String?
    public var disableMainThreadChecker: Bool
    public var commandLineArguments: [String: Bool]
    public var environmentVariables: [XCScheme.EnvironmentVariable]
    public var preActions: [Scheme.ExecutionAction]
    public var postActions: [Scheme.ExecutionAction]

    public init(
        testTargets: [Scheme.Test.TestTarget] = [],
        configVariants: [String] = [],
        gatherCoverageData: Bool = gatherCoverageDataDefault,
        language: String? = nil,
        region: String? = nil,
        disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
        commandLineArguments: [String: Bool] = [:],
        environmentVariables: [XCScheme.EnvironmentVariable] = [],
        preActions: [Scheme.ExecutionAction] = [],
        postActions: [Scheme.ExecutionAction] = []
    ) {
        self.testTargets = testTargets
        self.configVariants = configVariants
        self.gatherCoverageData = gatherCoverageData
        self.language = language
        self.region = region
        self.disableMainThreadChecker = disableMainThreadChecker
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
                    return .init(targetReference: try TargetReference(string))
                } else if let dictionary = target as? JSONDictionary {
                    return try .init(jsonDictionary: dictionary)
                } else {
                    return nil
                }
            }
        } else {
            testTargets = []
        }
        configVariants = jsonDictionary.json(atKeyPath: "configVariants") ?? []
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? TargetScheme.gatherCoverageDataDefault
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        disableMainThreadChecker = jsonDictionary.json(atKeyPath: "disableMainThreadChecker") ?? TargetScheme.disableMainThreadCheckerDefault
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
            "commandLineArguments": commandLineArguments,
            "testTargets": testTargets.map { $0.toJSONValue() },
            "environmentVariables": environmentVariables.map { $0.toJSONValue() },
            "preActions": preActions.map { $0.toJSONValue() },
            "postActions": postActions.map { $0.toJSONValue() },
        ]

        if gatherCoverageData != TargetScheme.gatherCoverageDataDefault {
            dict["gatherCoverageData"] = gatherCoverageData
        }

        if disableMainThreadChecker != TargetScheme.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
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
