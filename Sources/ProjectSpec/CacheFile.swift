import Foundation
import Core
import Version

public class CacheFile {

    public let string: String

    init?(version: Version, projectDictionary: [String: Any], project: Project) throws {

        guard #available(OSX 10.13, *) else { return nil }

        let files = Set(project.allFiles)
            .map { ((try? $0.relativePath(from: project.basePath)) ?? $0).string }
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
