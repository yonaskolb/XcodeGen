import Foundation
import JSONUtilities
import XcodeProj

extension Scheme {

    public struct Profile: BuildAction {
        public var config: String?
        public var commandLineArguments: [String: Bool]
        public var preActions: [ExecutionAction]
        public var postActions: [ExecutionAction]
        public var environmentVariables: [XCScheme.EnvironmentVariable]
        public init(
            config: String? = nil,
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
