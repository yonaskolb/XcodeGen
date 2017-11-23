import Foundation
import PathKit
import Commander
import XcodeGenKit
import xcproj
import ProjectSpec
import JSONUtilities

let version = "1.4.0"

func generate(spec: String, project: String, isQuiet: Bool) {
    let logger = Logger(isQuiet: isQuiet)

    func fatalError(_ message: String) -> Never {
        logger.error(message)
        exit(1)
    }

    let specPath = Path(spec).normalize()
    let projectPath = Path(project).normalize()

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
        try project.write(path: projectFile, override: true)
        logger.success("💾  Saved project to \(projectFile.string)")
    } catch let error as SpecValidationError {
        fatalError(error.description)
    } catch {
        fatalError("Generation failed: \(error.localizedDescription)")
    }
}

command(
    Option<String>("spec", "project.yml", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the folder where the project should be generated"),
    Flag("quiet", flag: "q", description: "Suppress printing of informational and success messages", default: false),
    generate
).run(version)
