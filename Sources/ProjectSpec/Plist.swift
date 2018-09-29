import Foundation
import JSONUtilities

public struct Plist: Equatable {

    public let path: String
    public let attributes: [String: Any]

    public init(path: String, attributes: [String: Any] = [:]) {
        self.path = path
        self.attributes = attributes
    }

    public static func == (lhs: Plist, rhs: Plist) -> Bool {
        return lhs.path == rhs.path &&
        NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

extension Plist: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
    }
}
