import Foundation
import XcodeProj
import JSONUtilities
import Version

public struct LocalSwiftPackage: Equatable {
    public let path: String
    
    public init(path: String) {
        self.path = path
    }
}

extension LocalSwiftPackage: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
    }
}

extension LocalSwiftPackage: JSONEncodable {
    public func toJSONValue() -> Any {
        var dictionary: JSONDictionary = [:]
        dictionary["path"] = path
        
        return dictionary
    }
}
