import Foundation
import JSONUtilities
import PathKit

public struct Plist: Equatable {

    public let path: Path
    public let properties: [String: Any]

    public init(path: Path, attributes: [String: Any] = [:]) {
        self.path = path
        properties = attributes
    }

    public static func == (lhs: Plist, rhs: Plist) -> Bool {
        lhs.path == rhs.path &&
            NSDictionary(dictionary: lhs.properties).isEqual(to: rhs.properties)
    }
}

extension Plist: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let pathString: String = try jsonDictionary.json(atKeyPath: "path")
        path = Path(pathString)
        properties = jsonDictionary.json(atKeyPath: "properties") ?? [:]
    }
}

extension Plist: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "path": path.string,
            "properties": properties,
        ]
    }
}

extension Plist: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("path"),
        ]
    }
}
