import Foundation
import SwiftCLI
import ProjectSpec
import XcodeGenKit
import PathKit
import Core

class ProjectCommand: Command {

    let version: Version
    var name: String { "ProjectCommand" }
    var shortDescription: String { "" }

    let spec = Key<Path>(
        "-s",
        "--spec",
        description: "The path to the project spec file. Defaults to project.yml"
    )

    let disableEnvExpansion = Flag(
        "-n",
        "--no-env",
        description: "Disable environment variable expansions",
        defaultValue: false
    )

    init(version: Version) {
        self.version = version
    }

    func execute() throws {

        let projectSpecPath = (spec.value ?? "project.yml").absolute()

        if !projectSpecPath.exists {
            throw GenerationError.missingProjectSpec(projectSpecPath)
        }

        let specLoader = SpecLoader(version: version)
        let project: Project

        let variables: [String: String] = disableEnvExpansion.value ? [:] : ProcessInfo.processInfo.environment

        do {
            project = try specLoader.loadProject(path: projectSpecPath, variables: variables)
        } catch {
            throw GenerationError.projectSpecParsingError(error)
        }

        try execute(specLoader: specLoader, projectSpecPath: projectSpecPath, project: project)
    }

    func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}
}
