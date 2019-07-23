import Foundation
import JSONUtilities

/// Describes an order of groups.
public struct GroupOrder: Equatable {
    
    public enum FileSortPosition: String {
        /// groups are at the top
        case top
        /// groups are at the bottom
        case bottom
    }
    
    /// A group name pattern.
    public var pattern: String
    
    /// Subgroups orders.
    public var order: [String]
    
    /// File sort position in a group.
    public var fileSortPosition: FileSortPosition = .top
    
}

extension GroupOrder: JSONObjectConvertible {
    
    public init(jsonDictionary: JSONDictionary) throws {
        pattern = jsonDictionary.json(atKeyPath: "pattern") ?? ""
        order = jsonDictionary.json(atKeyPath: "order") ?? []
        fileSortPosition = jsonDictionary.json(atKeyPath: "fileSortPosition") ?? .top
    }
    
}
