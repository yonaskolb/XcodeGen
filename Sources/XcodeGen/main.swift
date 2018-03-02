import Commander
import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeGenKit
import xcproj

let version = "1.6.0"

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

    let specPath = Path(spec).absolute()
    let projectPath = project == "" ? specPath.parent() : Path(project).absolute()

    if !specPath.exists {
        fatalError("No project spec found at \(specPath.absolute())")
    }

    let spec: ProjectSpec
    do {
        spec = try ProjectSpec(path: specPath)
        logger.info("📋  Loaded spec:\n  \(spec.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")
    } catch let error as JSONUtilities.DecodingError {
        fatalError("Parsing spec failed: \(error.description)")
    } catch {
        fatalError("Parsing spec failed: \(error.localizedDescription)")
    }

    do {
        logger.info("⚙️  Generating project...")
        let projectGenerator = ProjectGenerator(spec: spec)
        let project = try projectGenerator.generateProject()

        logger.info("⚙️  Writing project...")

        let projectFile = projectPath + "\(spec.name).xcodeproj"
        let tempPath = Path.temporary + "XcodeGen_\(Int(NSTimeIntervalSince1970))"
        try? tempPath.delete()
        if projectFile.exists {
            try projectFile.copy(tempPath)
        }
        try project.write(path: tempPath, override: true)
        try? projectFile.delete()
        try tempPath.copy(projectFile)
        try? tempPath.delete()

        logger.success("💾  Saved project to \(projectFile.string)")
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
        description: "The path to the spec file"
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
).run(version)
