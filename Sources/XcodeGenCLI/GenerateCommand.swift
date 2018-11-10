import Foundation
import SwiftCLI
import PathKit
import ProjectSpec
import XcodeGenKit
import xcodeproj

class GenerateCommand: Command {

    let name: String = "generate"
    let shortDescription: String = "Generate an Xcode project from a spec"

    let quiet = Flag("-q", "--quiet", description: "Suppress all informational and success output", defaultValue: false)

    let spec = Key<Path>("-s", "--spec", description: "The path to the project spec file. Defaults to project.yml")

    let projectDirectory = Key<Path>("-p", "--project", description: "The path to the directory where the project should be generated. Defaults to the directory the spec is in. The filename is defined in the project spec")

    let version: Version

    init(version: Version) {
        self.version = version
    }

    func execute() throws {

        let projectSpecPath = (spec.value ?? "project.yml").absolute()

        let projectDirectory = self.projectDirectory.value?.absolute() ?? projectSpecPath.parent()

        if !projectSpecPath.exists {
            throw GenerationError.missingProjectSpec(projectSpecPath)
        }

        let project: Project
        do {
            project = try Project(path: projectSpecPath)
        } catch {
            throw GenerationError.projectSpecParsingError(error)
        }

        info("📋  Loaded project:\n  \(project.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")

        do {
            try project.validateMinimumXcodeGenVersion(version)
            try project.validate()
        } catch let error as SpecValidationError {
            throw GenerationError.validationError(error)
        }

        info("⚙️  Generating project...")
        let xcodeProject: XcodeProj
        do {
            let projectGenerator = ProjectGenerator(project: project)
            xcodeProject = try projectGenerator.generateXcodeProject()
        } catch {
            throw GenerationError.generationError(error)
        }

        info("⚙️  Writing project...")
        let projectPath = projectDirectory + "\(project.name).xcodeproj"
        do {

            let fileWriter = FileWriter(project: project)
            try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)
            try fileWriter.writePlists()
        } catch {
            throw GenerationError.writingError(error)
        }

        success("💾  Saved project to \(projectPath)")
    }

    func info(_ string: String) {
        if !quiet.value {
            stdout.print(string)
        }
    }

    func success(_ string: String) {
        if !quiet.value {
            stdout.print(string.green)
        }
    }
}
