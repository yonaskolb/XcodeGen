import Foundation
import JSONUtilities
import PathKit
import XcodeProj
import Yams
import Version

private extension Project {
    func referencesSatisfied(with projects: [Project]) -> Bool {
        // FIXME: Project.projectReferences do not contain enough information to assess this correclty all the time.
        // This is because we don't know the references 'correct' output path until we load the spec (and read the real `name`).
        // To overcome this, we should pass some data from `loadedProjects` that helps better resolve a spec path to a loaded project, that way we can be 100% sure...
        // we'd also need to be a bit careful about cases where differnet specs reference the same spec to different output directories. This is something we could assess at laod time and error about.
        let availableProjectPaths = projects.map({ $0.basePath.absolute() })
        return projectReferences
            .filter { $0.spec != nil }
            .allSatisfy { availableProjectPaths.contains((basePath + $0.path).parent().absolute()) }
    }
}

public class SpecLoader {

    var project: Project!
    public private(set) var projectDictionary: [String: Any]?
    let version: Version

    public init(version: Version) {
        self.version = version
    }

    public func loadProjects(path: Path, projectRoot: Path? = nil, variables: [String: String] = [:]) throws -> [Project] {
        // 1: Load the root project.
        let rootProject = try loadProject(path: path, projectRoot: projectRoot, variables: variables)

        // 2: Find references and recursevly load them until we have everything in memory.
        var loadedProjects: [Path: Project] = [rootProject.defaultProjectPath.absolute(): rootProject]
        try loadReferencedProjects(in: rootProject, variables: variables, into: &loadedProjects, relativeTo: path.parent())

        // 3: Order the projects to generate without missing references
        var projects: [Project] = []
        while !loadedProjects.isEmpty {
            // 4. Find the first project from `loadedProject` that can be generated with the items currently defined in `projects`. This helps determine the correct order to run the generator command.
            guard let (key, project) = loadedProjects.first(where: { $0.value.referencesSatisfied(with: projects) }) else {
                throw NSError(domain: "", code: 0, userInfo: nil) // TODO: Add to GeneratorError with correct order
            }

            // 5. Remove from `loadedProjects` and insert in `projects` since we've now resolved this project
            loadedProjects[key] = nil
            projects.append(project)
        }

        // 4. Return the projects ready for generating in defined order
        print("Resolved projects in order:")
        projects.enumerated().forEach { print("\($0.offset + 1).", $0.element.defaultProjectPath.string) }
        return projects
    }

    private func loadReferencedProjects(
        in project: Project,
        variables: [String: String],
        into store: inout [Path: Project],
        relativeTo relativePath: Path
    ) throws {
        // Enumerate dependencies and see if there are other specs to load
        for projectReference in project.projectReferences {
            // If the refernece doesn't specify a spec then ignore it since we assume that it's a non-generated project
            guard let spec = projectReference.spec else { continue }

            // Work out the path to the spec that we need to load
            let path = (relativePath + spec).absolute()

            // Work out the directory which the project will be generated into, ignore the project name since that will be decided based on the spec once loaded.
            // We might want to warn or error if there re inconsistencies though.
            let projectRoot = (relativePath + projectReference.path).parent()

            // Load the project, read the path that it resolved to (this uses the name from inside the spec, rather than the reference name that could be wrong)
            let project = try loadProject(path: path, projectRoot: projectRoot, variables: variables)
            let projectPath = project.defaultProjectPath.absolute()

            // TODO: Error if a matching loaded project in the `store` originated from a different spec.
            // This could be a scenario where two differnet spec files define the same `projectReference.path` but associate the `spec`'s to differnet yaml files.

            // Skip this reference if we've already loaded the project once before, no need to do so twice
            guard store[projectPath] == nil else {
                continue
            }

            // Store the loaded project so that we don't load it again if it's referenced by a different spec
            store[projectPath] = project

            // Repeat the process for any references in the newly loaded project
            try loadReferencedProjects(in: project, variables: variables, into: &store, relativeTo: path.parent())
        }
    }

    public func loadProject(path: Path, projectRoot: Path? = nil, variables: [String: String] = [:]) throws -> Project {
        let spec = try SpecFile(path: path)
        let resolvedDictionary = spec.resolvedDictionary(variables: variables)
        let project = try Project(basePath: projectRoot ?? spec.basePath, jsonDictionary: resolvedDictionary)

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
        let errors: [SpecValidationError.ValidationError] = []

        if !errors.isEmpty {
            throw SpecValidationError(errors: errors)
        }
    }

    func hasValueContaining(_ needle: String) -> Bool {
        values.contains { value in
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
