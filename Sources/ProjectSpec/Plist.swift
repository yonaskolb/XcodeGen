import Foundation
import JSONUtilities
import struct PathKit.Path

public struct Plist: Equatable {

    public let path: String
    public let properties: [String: Any]

    public init(path: String, attributes: [String: Any] = [:]) {
        self.path = path
        properties = attributes
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

extension Plist: PathContaining {
    static func expandPaths(for source: JSONDictionary, relativeTo path: Path) -> JSONDictionary {
        return expandStringPaths(from: source, forKey: "path", relativeTo: path)
    }
}
