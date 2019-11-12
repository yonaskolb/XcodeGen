import Foundation
import JSONUtilities

extension Scheme {

    public struct Analyze: BuildAction {
        public var config: String?
        public init(config: String) {
            self.config = config
        }
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
