import Foundation
import JSONUtilities

public struct ProjectReference: Hashable {
    public var name: String
    public var path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

extension ProjectReference: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .string("path"),
            ]),
        ]
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
        [
            "path": path,
        ]
    }
}
