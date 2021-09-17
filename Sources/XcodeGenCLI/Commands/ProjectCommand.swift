import Foundation
import SwiftCLI
import ProjectSpec
import XcodeGenKit
import PathKit
import XcodeGenCore
import Version

class ProjectCommand: Command, LogRenderer {

    let version: Version
    let name: String
    let shortDescription: String

    @Key("-s", "--spec", description: "The path to the project spec file. Defaults to project.yml")
    var spec: Path?

    @Key("-r", "--project-root", description: "The path to the project root directory. Defaults to the directory containing the project spec.")
    var projectRoot: Path?

    @Flag("-n", "--no-env", description: "Disable environment variable expansions")
    var disableEnvExpansion: Bool

    @Flag("-q", "--quiet", description: "Suppress all informational and success output")
    var quiet: Bool

    @Flag("-d", "--debug", description: "Render all messages including debug (--quiet overrides this flag)")
    var debug: Bool

    init(version: Version, name: String, shortDescription: String) {
        self.version = version
        self.name = name
        self.shortDescription = shortDescription
    }

    func setupLogger() {
        Logger.shared.delegate = self

        if quiet {
            Logger.shared.logLevel = .error
        } else if debug {
            Logger.shared.logLevel = .debug
        } else {
            Logger.shared.logLevel = .info
        }
    }

    func execute() throws {
        setupLogger()

        let projectSpecPath = (spec ?? "project.yml").absolute()

        Logger.shared.debug("Checking for spec file: \(projectSpecPath)")

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

        Logger.shared.debug("Loaded project")

        try execute(specLoader: specLoader, projectSpecPath: projectSpecPath, project: project)
    }

    func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {}


    func debug(_ string: String) {
        stdout.print("[DEBUG] \(string)")
    }

    func info(_ string: String, wasSuccess: Bool) {
        var coloredString = string
        if wasSuccess {
            coloredString = coloredString.green
        }
        stdout.print("[INFO] \(coloredString)")
    }

    func warning(_ string: String) {
        stdout.print("[WARNING] \(string)".yellow)
    }

    func error(_ string: String) {
        stderr.print("[ERROR] \(string)".red)
    }
}
