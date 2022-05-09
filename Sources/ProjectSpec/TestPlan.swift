import Foundation
import JSONUtilities

public struct TestPlan: Equatable {
    public var path: String
    public var defaultPlan: Bool

    public init(path: String, defaultPlan: Bool = false) {
        self.defaultPlan = defaultPlan
        self.path = path
    }
}


extension TestPlan: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        defaultPlan = jsonDictionary.json(atKeyPath: "defaultPlan") ?? false
    }
}

extension TestPlan: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "path": path,
            "defaultPlan": defaultPlan,
        ]
    }
}

extension TestPlan: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("path"),
        ]
    }
}
