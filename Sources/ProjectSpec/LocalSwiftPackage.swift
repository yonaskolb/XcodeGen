import Foundation
import XcodeProj
import JSONUtilities
import Version

public struct LocalSwiftPackage: Equatable {
    public let path: String
}

extension LocalSwiftPackage: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
    }
}
