import Foundation
import JSONUtilities

public protocol JSONDictionaryEncodable {
    func toJSONDictionary() -> JSONDictionary
}

public protocol JSONArrayEncodable {
    func toJSONArray() -> JSONArray
}

public protocol JSONPrimitiveEncodable {
    func toJSONValue() -> JSONRawType
}

public protocol JSONDynamicEncodable {
    // returns JSONDictionary or JSONArray or JSONRawType
    func toJSONValue() -> Any
}
