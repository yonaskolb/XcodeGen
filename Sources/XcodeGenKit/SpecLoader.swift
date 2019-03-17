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

    public func validateProjectDictionaryWarnings() throws {
        try projectDictionary?.validateWarnings()
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

private extension Dictionary where Key == String, Value: Any {

    func validateWarnings() throws {
        var errors: [SpecValidationError.ValidationError] = []
        if hasValueContaining("$target_name") {
            errors.append(.deprecatedUsageOfPlaceholder(placeholderName: "target_name"))
        }
        if hasValueContaining("$platform") {
            errors.append(.deprecatedUsageOfPlaceholder(placeholderName: "platform"))
        }
        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }

    func hasValueContaining(_ needle: String) -> Bool {
        return values.contains { value in
            switch value {
            case let dictionary as JSONDictionary:
                return dictionary.hasValueContaining(needle)
            case let string as String:
                return string.contains(needle)
            case let array as [JSONDictionary]:
                return array.contains { $0.hasValueContaining(needle) }
            case let array as [String]:
                return array.contains { $0.contains(needle) }
            default:
                return false
            }
        }
    }
}
