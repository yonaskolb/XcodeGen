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

    let specPath = Path(spec).normalize()
    let projectPath = Path(project).normalize()

    if !specPath.exists {
        logger.fatal("No project spec found at \(specPath.absolute())")
        exit(1)
    }

    let spec: ProjectSpec
    do {
        spec = try ProjectSpec(path: specPath)
        logger.info("📋  Loaded spec:\n  \(spec.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")
    } catch let error as JSONUtilities.DecodingError {
        logger.fatal("Parsing spec failed: \(error.description)")
        exit(1)
    } catch {
        logger.fatal("Parsing spec failed: \(error.localizedDescription)")
        exit(1)
    }

    do {
        let projectGenerator = ProjectGenerator(spec: spec)
        let project = try projectGenerator.generateProject()
        logger.info("⚙️  Generated project")

        let projectFile = projectPath + "\(spec.name).xcodeproj"
        try project.write(path: projectFile, override: true)
        logger.success("💾  Saved project to \(projectFile.string)")
    } catch let error as SpecValidationError {
        logger.fatal(error.description)
        exit(1)
    } catch {
        logger.fatal("Generation failed: \(error.localizedDescription)")
        exit(1)
    }
}

command(
    Option<String>("spec", "project.yml", flag: "s", description: "The path to the spec file"),
    Option<String>("project", "", flag: "p", description: "The path to the folder where the project should be generated"),
    Flag("quiet", flag: "q", description: "Suppress printing of informational and success messages", default: false),
    generate
).run(version)
