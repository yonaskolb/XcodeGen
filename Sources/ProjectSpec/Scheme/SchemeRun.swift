import Foundation
import XcodeProj
import JSONUtilities

extension Scheme {

    public struct Run: BuildAction {
        public static let disableMainThreadCheckerDefault = false
        public static let debugEnabledDefault = true

        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public var disableMainThreadChecker: Bool
        public var language: String?
        public var region: String?
        public var debugEnabled: Bool

        public init(
            config: String? = nil,
            commandLineArguments: [String: Bool] = [:],
            preActions: [ExecutionAction] = [],
            postActions: [ExecutionAction] = [],
            environmentVariables: [XCScheme.EnvironmentVariable] = [],
            disableMainThreadChecker: Bool = disableMainThreadCheckerDefault,
            language: String? = nil,
            region: String? = nil,
            debugEnabled: Bool = debugEnabledDefault
        ) {
            self.config = config
            self.commandLineArguments = commandLineArguments
            self.preActions = preActions
            self.postActions = postActions
            self.environmentVariables = environmentVariables
            self.disableMainThreadChecker = disableMainThreadChecker
            self.language = language
            self.region = region
            self.debugEnabled = debugEnabled
        }
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
        language = jsonDictionary.json(atKeyPath: "language")
        region = jsonDictionary.json(atKeyPath: "region")
        debugEnabled = jsonDictionary.json(atKeyPath: "debugEnabled") ?? Scheme.Run.debugEnabledDefault
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
        ]

        if disableMainThreadChecker != Scheme.Run.disableMainThreadCheckerDefault {
            dict["disableMainThreadChecker"] = disableMainThreadChecker
        }

        if debugEnabled != Scheme.Run.debugEnabledDefault {
            dict["debugEnabled"] = debugEnabled
        }
        return dict
    }
}
