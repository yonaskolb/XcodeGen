import Foundation
import JSONUtilities

public struct ProjectReference {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

extension ProjectReference: NamedJSONDictionaryConvertible {
    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        self.path = try jsonDictionary.json(atKeyPath: "path")
    }
}

extension ProjectReference: JSONEncodable {
    public func toJSONValue() -> Any {
        return [
            "path": path,
        ]
    }
}
