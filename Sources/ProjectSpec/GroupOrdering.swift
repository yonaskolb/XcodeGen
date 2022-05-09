import Foundation
import JSONUtilities

/// Describes an order of groups.
public struct GroupOrdering: Equatable {

    /// A group name pattern.
    public var pattern: String

    /// A group name regex.
    public var regex: NSRegularExpression?

    /// Subgroups orders.
    public var order: [String]

    public init(pattern: String = "", order: [String] = []) {
        self.pattern = pattern
        self.regex = try? NSRegularExpression(pattern: pattern)
        self.order = order
    }

}

extension GroupOrdering: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        pattern = jsonDictionary.json(atKeyPath: "pattern") ?? ""
        regex = try? NSRegularExpression(pattern: pattern)
        order = jsonDictionary.json(atKeyPath: "order") ?? []
    }

}
