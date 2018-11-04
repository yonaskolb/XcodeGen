import Commander
import Foundation
import JSONUtilities
import PathKit
import ProjectSpec
import XcodeGenKit
import xcodeproj
import Yams

let version = try Version("2.0.0")

func generate(spec: String, project: String, useCache: Bool, isQuiet: Bool, justVersion: Bool) {
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

    let specLoader = SpecLoader(version: version)
    let project: Project

    // load project spec
    do {
        project = try specLoader.loadProject(path: projectSpecPath)
        projectPath = projectPath + "\(project.name).xcodeproj"
    } catch let error as CustomStringConvertible {
        fatalError("Parsing project spec failed: \(error)")
    } catch {
        fatalError("Parsing project spec failed: \(error.localizedDescription)")
    }

    let cacheFilePath = Path("~/.xcodegen/cache/\(projectSpecPath.absolute().string.md5)").absolute()
    var cacheFile: CacheFile?

    // read cache
    if useCache {
        do {
            cacheFile = try specLoader.generateCacheFile()
        } catch {
            logger.error("Couldn't generate cache file: \(error.localizedDescription)")
        }
    }

    // check cache
    if let cacheFile = cacheFile,
        projectPath.exists,
        cacheFilePath.exists {
        do {
            let existingCacheFile: String = try cacheFilePath.read()
            if cacheFile.string == existingCacheFile {
                logger.success("Project has not changed since cache was written")
                return
            }
        } catch {
            logger.error("Couldn't load cache at \(cacheFile)")
        }
    }

    logger.info("Loaded project:\n  \(project.debugDescription.replacingOccurrences(of: "\n", with: "\n  "))")

    do {
        // validation
        try project.validateMinimumXcodeGenVersion(version)
        try project.validate()

        // generation
        logger.info("⚙️  Generating project...")
        let projectGenerator = ProjectGenerator(project: project)
        let xcodeProject = try projectGenerator.generateXcodeProject()

        // file writing
        logger.info("⚙️  Writing project...")
        let fileWriter = FileWriter(project: project)
        try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)
        try fileWriter.writePlists()

        logger.success("💾  Saved project to \(projectPath)")
    } catch let error as SpecValidationError {
        fatalError(error.description)
    } catch {
        fatalError("Generation failed: \(error.localizedDescription)")
    }

    // write cache
    if let cacheFile = cacheFile {
        do {
            try cacheFilePath.parent().mkpath()
            try cacheFilePath.write(cacheFile.string)
        } catch {
            logger.error("Failed to write cache: \(error.localizedDescription)")
        }
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
        "use-cache",
        default: false,
        flag: "c",
        description: "Use a cache for the xcodegen spec"
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
