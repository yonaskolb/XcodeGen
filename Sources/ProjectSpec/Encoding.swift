import Foundation
import JSONUtilities

public protocol JSONEncodable {
    // returns JSONDictionary or JSONArray or JSONRawType
    func toJSONValue() -> Any
}
