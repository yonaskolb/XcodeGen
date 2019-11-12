import Foundation
import JSONUtilities

extension Scheme {
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
