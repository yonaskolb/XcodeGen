import Foundation
import Yams
import PathKit

public func loadYamlDictionary(path: Path) throws -> [String: Any] {
    let string: String = try path.read()
    if string == "" {
        return [:]
    }
    guard let yaml = try Yams.load(yaml: string) else {
        return [:]
    }
    return filterNull(yaml) as? [String: Any] ?? [:]
}

fileprivate func filterNull(_ object: Any) -> Any {
    var returnedValue: Any = object
    if let dict = object as? [String: Any] {
        var mutabledic: [String: Any] = [:]
        for (key, value) in dict {
            mutabledic[key] = filterNull(value)
        }
        returnedValue = mutabledic
    } else if let array = object as? [Any] {
        var mutableArray: [Any] = array
        for (index, value) in array.enumerated() {
            mutableArray[index] = filterNull(value)
        }
        returnedValue = mutableArray
    }
    return (object is NSNull) ? "" : returnedValue
}
