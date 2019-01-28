import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import xcodeproj
import Yams

public class SpecLoader {

    var project: Project!
    private var projectDictionary: [String: Any]?
    let version: Version

    public init(version: Version) {
        self.version = version
    }

    public func loadProject(path: Path) throws -> Project {
        let spec = try SpecFile(path: path)
        let resolvedDictionary = spec.resolvedDictionary()
        let project = try Project(basePath: spec.basePath, jsonDictionary: resolvedDictionary)

        self.project = project
        projectDictionary = resolvedDictionary

        return project
    }

    public func generateCacheFile() throws -> CacheFile? {
        guard let projectDictionary = projectDictionary,
            let project = project else {
            return nil
        }
        return try CacheFile(
            version: version,
            projectDictionary: projectDictionary,
            project: project
        )
    }
}
