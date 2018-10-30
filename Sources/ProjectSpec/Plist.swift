import Foundation
import JSONUtilities

public struct Plist: Equatable {

    public let path: String
    public let properties: [String: Any]

    public init(path: String, attributes: [String: Any] = [:]) {
        self.path = path
        self.properties = attributes
    }

    public static func == (lhs: Plist, rhs: Plist) -> Bool {
        return lhs.path == rhs.path &&
        NSDictionary(dictionary: lhs.properties).isEqual(to: rhs.properties)
    }
}

extension Plist: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        properties = jsonDictionary.json(atKeyPath: "properties") ?? [:]
    }
}
