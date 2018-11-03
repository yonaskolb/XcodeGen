import Foundation
import ProjectSpec


public class CacheFile {

    public let string: String

    init?(version: Version, projectDictionary: [String: Any], project: Project) throws {

        guard #available(OSX 10.13, *) else { return nil }

        let files = Array(Set(project.allFiles))
            .map { $0.byRemovingBase(path: project.basePath).string }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .joined(separator: "\n")

        let data = try JSONSerialization.data(withJSONObject: projectDictionary, options: [.sortedKeys, .prettyPrinted])
        let spec = String(data: data, encoding: .utf8)!

        string = """
        # XCODEGEN VERSION
        \(version)

        # SPEC
        \(spec)

        # FILES
        \(files)"

        """
    }
}
