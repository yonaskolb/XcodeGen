import Foundation

private protocol EmptyRemovable {
    func removeEmpty() -> Self
    var isEmpty: Bool { get }
}

extension Array: EmptyRemovable {
    public func removeEmpty() -> Array {
        return compactMap {
            if let e = ($0 as? EmptyRemovable)?.removeEmpty() {
                return e.isEmpty ? nil : e as? Element
            }
            return $0
        }
    }
}

extension Dictionary: EmptyRemovable {
    // this is a little trick that defines the generics parameter from optional Value to unwrapped Value
    private static func removeEmpty<Key, Value>(dict: Dictionary<Key, Value?>) -> Dictionary<Key, Value> {
        return dict.compactMapValues {
            if let e = ($0 as? EmptyRemovable)?.removeEmpty() {
                return e.isEmpty ? nil : e as? Value
            }
            return $0
        }
    }

    public func removeEmpty() -> Dictionary<Key, Value> {
        return Dictionary.removeEmpty(dict: self)
    }
}
