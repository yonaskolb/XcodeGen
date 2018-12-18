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
        let dictionary = try Project.loadDictionary(path: path)
        let project = try Project(basePath: path.parent(), jsonDictionary: dictionary)

        self.project = project
        self.projectDictionary = dictionary

        return project
    }

    public func generateCacheFile() throws -> CacheFile? {
        guard let projectDictionary = projectDictionary,
            let project = project else {
                return nil
        }
        return try CacheFile(version: version,
                              projectDictionary: projectDictionary,
                              project: project)
    }

}
