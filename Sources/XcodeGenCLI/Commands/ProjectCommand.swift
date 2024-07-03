import Foundation
import SwiftCLI
import ProjectSpec
import XcodeGenKit
import PathKit
import XcodeGenCore
import Version

class ProjectCommand: Command {

    let version: Version
    let name: String
    let shortDescription: String

    @Flag("-q", "--quiet", description: "Suppress all informational and success output")
    var quiet: Bool
    
    @Key("-s", "--spec", description: "The path to the project spec file. Defaults to project.yml. (It is also possible to link to multiple spec files by comma separating them. Note that all other flags will be the same.)")
    var spec: String?

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
        
        var projectSpecs: [Path] = []
        if let spec = spec {
            projectSpecs = spec.components(separatedBy: ",").map { Path($0).absolute() }
        } else {
            projectSpecs = [ Path("project.yml").absolute() ]
        }
        
        for projectSpecPath in projectSpecs {
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
    }

    func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}

    func info(_ string: String) {
        if !quiet {
            stdout.print(string)
        }
    }

    func warning(_ string: String) {
        if !quiet {
            stdout.print(string.yellow)
        }
    }

    func success(_ string: String) {
        if !quiet {
            stdout.print(string.green)
        }
    }
}
