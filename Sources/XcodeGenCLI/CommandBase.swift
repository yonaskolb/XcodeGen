import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj

class CommandBase: Command {

    var name: String {
        return ""
    }

    let quiet = Flag(
        "-q",
        "--quiet",
        description: "Suppress all informational and success output",
        defaultValue: false
    )

    let spec = Key<Path>(
        "-s",
        "--spec",
        description: "The path to the project spec file. Defaults to project.yml"
    )

    let projectDirectory = Key<Path>("-p", "--project", description: "The path to the directory where the project should be generated. Defaults to the directory the spec is in. The filename is defined in the project spec")

    lazy var specLoader = SpecLoader(version: version)

    let version: Version

    init(version: Version) {
        self.version = version
    }

    func execute() throws {
        fatalError("execute() has not been implemented")
    }

    func getProjectPath() throws -> Path {
        let projectSpecPath = (spec.value ?? "project.yml").absolute()

        if !projectSpecPath.exists {
            throw GenerationError.missingProjectSpec(projectSpecPath)
        }
        return projectSpecPath
    }

    func getProjectDir(from specPath: Path) -> Path {
        return projectDirectory.value?.absolute() ?? specPath.parent()
    }

    func getProject(from specPath: Path) throws -> Project {
        // load project spec
        do {
            let project = try specLoader.loadProject(path: specPath, variables: ProcessInfo.processInfo.environment)
            return project
        } catch {
            throw GenerationError.projectSpecParsingError(error)
        }
    }

    func info(_ string: String) {
        if !quiet.value {
            stdout.print(string)
        }
    }

    func warning(_ string: String) {
        if !quiet.value {
            stdout.print(string.yellow)
        }
    }

    func success(_ string: String) {
        if !quiet.value {
            stdout.print(string.green)
        }
    }
}
