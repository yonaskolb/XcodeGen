import Foundation
import XcodeProj
import PathKit

/// Computes a structural diff between two XcodeProj objects.
/// Comparison is by name/path — UUIDs are ignored for stability.
public struct ProjectDiff: Encodable {

    public let changed: Bool
    public let targetsAdded: [String]
    public let targetsRemoved: [String]
    public let filesAdded: [String]
    public let filesRemoved: [String]

    public init(from newProject: XcodeProj, against existingPath: Path?) {
        let newTargetNames = Set(newProject.pbxproj.nativeTargets.map { $0.name })
        let newFilePaths = ProjectDiff.sourcePaths(from: newProject)

        guard let existingPath = existingPath, existingPath.exists,
              let existing = try? XcodeProj(path: existingPath) else {
            // No existing project — everything is "added"
            targetsAdded = newTargetNames.sorted()
            targetsRemoved = []
            filesAdded = newFilePaths.sorted()
            filesRemoved = []
            changed = !targetsAdded.isEmpty || !filesAdded.isEmpty
            return
        }

        let existingTargetNames = Set(existing.pbxproj.nativeTargets.map { $0.name })
        let existingFilePaths = ProjectDiff.sourcePaths(from: existing)

        targetsAdded = newTargetNames.subtracting(existingTargetNames).sorted()
        targetsRemoved = existingTargetNames.subtracting(newTargetNames).sorted()
        filesAdded = newFilePaths.subtracting(existingFilePaths).sorted()
        filesRemoved = existingFilePaths.subtracting(newFilePaths).sorted()
        changed = !targetsAdded.isEmpty || !targetsRemoved.isEmpty
                || !filesAdded.isEmpty || !filesRemoved.isEmpty
    }

    private static func sourcePaths(from project: XcodeProj) -> Set<String> {
        var paths = Set<String>()
        for target in project.pbxproj.nativeTargets {
            let files = (try? target.sourceFiles()) ?? []
            for file in files {
                if let path = file.path {
                    paths.insert(path)
                }
            }
        }
        return paths
    }

    public func jsonString() throws -> String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
