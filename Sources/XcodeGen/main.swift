import Commander
import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeGenKit
import xcodeproj

let version = try Version("2.0.0")

func generate(spec: String, project: String, isQuiet: Bool, justVersion: Bool) {
    if justVersion {
        print(version)
        exit(EXIT_SUCCESS)
    }

    let logger = Logger(isQuiet: isQuiet)

    func fatalError(_ message: String) -> Never {
        logger.error(message)
        exit(1)
    }

    let projectSpecPath = Path(spec).absolute()
    var projectPath = project == "" ? projectSpecPath.parent() : Path(project).absolute()

    if !projectSpecPath.exists {
        fatalError("No project spec found at \(projectSpecPath.absolute())")
    }

    let project: Project
    do {
        project = try Project(path: projectSpecPath)
        logger.info("📋  Loaded project:\n  \(project.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")
    } catch let error as CustomStringConvertible {
        fatalError("Parsing project spec failed: \(error)")
    } catch {
        fatalError("Parsing project spec failed: \(error.localizedDescription)")
    }

    do {
        try project.validateMinimumXcodeGenVersion(version)
        try project.validate()

        logger.info("⚙️  Generating project...")
        let projectGenerator = ProjectGenerator(project: project)
        let xcodeProject = try projectGenerator.generateXcodeProject()

        logger.info("⚙️  Writing project...")
        let fileWriter = FileWriter(project: project)
        projectPath = projectPath + "\(project.name).xcodeproj"
        try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)
        try fileWriter.writePlists()

        logger.success("💾  Saved project to \(projectPath)")
    } catch let error as SpecValidationError {
        fatalError(error.description)
    } catch {
        fatalError("Generation failed: \(error.localizedDescription)")
    }
}

command(
    Option<String>(
        "spec",
        default: "project.yml",
        flag: "s",
        description: "The path to the project spec file"
    ),
    Option<String>(
        "project",
        default: "",
        flag: "p",
        description: "The path to the folder where the project should be generated"
    ),
    Flag(
        "quiet",
        default: false,
        flag: "q",
        description: "Suppress printing of informational and success messages"
    ),
    Flag(
        "version",
        default: false,
        flag: "v",
        description: "Show XcodeGen version"
    ),
    generate
).run(version.description)
