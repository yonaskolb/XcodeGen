import Foundation

private func convertEmptyToNil<T>(_ value: T) -> T? {
    switch value as Any {
    case Optional<Any>.none:
        return nil
    case let arr as Array<Any>:
        let arr = arr.removeEmpty()
        if !arr.isEmpty,
           let arr = arr as? T {
            return arr
        } else {
            return nil
        }
    case let dict as Dictionary<AnyHashable, Any>:
        let dict = dict.removeEmpty()
        if !dict.isEmpty,
           let dict = dict as? T {
            return dict
        } else {
            return nil
        }
    default:
        return value
    }
}

extension Array {
    public func removeEmpty() -> Self {
        compactMap(convertEmptyToNil)
    }
}

extension Dictionary {
    public func removeEmpty() -> Self {
        compactMapValues(convertEmptyToNil)
    }
}
