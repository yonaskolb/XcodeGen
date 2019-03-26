import Foundation
import JSONUtilities
import xcodeproj

public struct TargetScheme: Equatable {
    public var testTargets: [Scheme.Test.TestTarget]
    public var configVariants: [String]
    public var gatherCoverageData: Bool
    public var commandLineArguments: [String: Bool]
    public var environmentVariables: [XCScheme.EnvironmentVariable]
    public var preActions: [Scheme.ExecutionAction]
    public var postActions: [Scheme.ExecutionAction]

    public init(
        testTargets: [Scheme.Test.TestTarget] = [],
        configVariants: [String] = [],
        gatherCoverageData: Bool = false,
        commandLineArguments: [String: Bool] = [:],
        environmentVariables: [XCScheme.EnvironmentVariable] = [],
        preActions: [Scheme.ExecutionAction] = [],
        postActions: [Scheme.ExecutionAction] = []
    ) {
        self.testTargets = testTargets
        self.configVariants = configVariants
        self.gatherCoverageData = gatherCoverageData
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
                    return .init(name: string)
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
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
    }
}

extension TargetScheme: JSONDictionaryEncodable {
    public func toJSONDictionary() -> JSONDictionary {
        var dict: JSONDictionary = [
            "gatherCoverageData": gatherCoverageData,
        ]

        if configVariants.count > 0 {
            dict["configVariants"] = configVariants
        }
        if commandLineArguments.count > 0 {
            dict["commandLineArguments"] = commandLineArguments
        }
        if testTargets.count > 0 {
            dict["testTargets"] = testTargets.map { $0.toJSONValue() }
        }
        if environmentVariables.count > 0 {
            dict["environmentVariables"] = environmentVariables.map { $0.toJSONDictionary() }
        }
        if preActions.count > 0 {
            dict["preActions"] = preActions.map { $0.toJSONDictionary() }
        }
        if postActions.count > 0 {
            dict["postActions"] = postActions.map { $0.toJSONDictionary() }
        }

        return dict
    }
}
