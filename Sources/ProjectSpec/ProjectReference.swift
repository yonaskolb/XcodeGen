import Foundation
import JSONUtilities

public struct ProjectReference: Hashable {
    public var name: String
    public var path: String
    public var spec: String?

    public init(name: String, path: String, spec: String?) {
        self.name = name
        self.path = path
        self.spec = spec
    }
}

extension ProjectReference: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .string("path"),
                .string("spec")
            ]),
        ]
    }
}

extension ProjectReference: NamedJSONDictionaryConvertible {
    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        self.path = try jsonDictionary.json(atKeyPath: "path")
        self.spec = jsonDictionary.json(atKeyPath: "spec")
    }
}

extension ProjectReference: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "path": path,
            "spec": spec
        ]
    }
}
