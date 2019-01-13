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
}
