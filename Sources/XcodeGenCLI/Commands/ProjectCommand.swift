import Foundation
import SwiftCLI
import ProjectSpec
import XcodeGenKit
import PathKit
import Core
import Version

class ProjectCommand: Command {

    let version: Version
    let name: String
    let shortDescription: String

    @Key("-s", "--spec", description: "The path to the project spec file. Defaults to project.yml")
    var spec: Path?

    @Key("-r", "--project-root", description: "The path to the project root directory. Defaults to the directory containing the project spec.")
    var projectRoot: Path?

    @Flag("-n", "--no-env", description: "Disable environment variable expansions")
    var disableEnvExpansion: Bool

    init(version: Version, name: String, shortDescription: String) {
        self.version = version
        self.name = name
        self.shortDescription = shortDescription
    }

    func execute() throws {

        let projectSpecPath = (spec ?? "project.yml").absolute()

        if !projectSpecPath.exists {
            throw GenerationError.missingProjectSpec(projectSpecPath)
        }

        let specLoader = SpecLoader(version: version)
        let project: Project

        let variables: [String: String] = disableEnvExpansion ? [:] : ProcessInfo.processInfo.environment

        do {
            project = try specLoader.loadProject(path: projectSpecPath, projectRoot: projectRoot, variables: variables)
        } catch {
            throw GenerationError.projectSpecParsingError(error)
        }

        try execute(specLoader: specLoader, projectSpecPath: projectSpecPath, project: project)
    }

    func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}
}
