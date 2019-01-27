import Foundation
import JSONUtilities
import PathKit
import Yams

extension Project {
    
    public init(path: Path) throws {
        let basePath = path.parent()
        let template = try Spec(filename: path.lastComponent, basePath: basePath)
        try self.init(spec: template, basePath: basePath)
    }

    public static func loadDictionary(path: Path) throws -> JSONDictionary {
        return try Project.Spec(filename: path.lastComponent, basePath: path.parent()).jsonDictionary
    }
}

protocol PathContainer {

    static var pathProperties: [PathProperty] { get }
}

enum PathProperty {
    case string(String)
    case dictionary([PathProperty])
    case object(String, [PathProperty])
}
