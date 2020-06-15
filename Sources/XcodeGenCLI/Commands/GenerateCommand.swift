import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Version

class GenerateCommand: ProjectCommand {

    @Flag("-q", "--quiet", description: "Suppress all informational and success output")
    var quiet: Bool

    @Flag("-c", "--use-cache", description: "Use a cache for the xcodegen spec. This will prevent unnecessarily generating the project if nothing has changed")
    var useCache: Bool

    @Key("--cache-path", description: "Where the cache file will be loaded from and save to. Defaults to ~/.xcodegen/cache/{SPEC_PATH_HASH}")
    var cacheFilePath: Path?

    @Key("-p", "--project", description: "The path to the directory where the project should be generated. Defaults to the directory the spec is in. The filename is defined in the project spec")
    var projectDirectory: Path?

    @Flag("--only-plists", description: "Generate only plist files")
    var onlyPlists: Bool

    init(version: Version) {
        super.init(version: version,
                   name: "generate",
                   shortDescription: "Generate an Xcode project from a spec")
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {

        // TODO: Is it this easy?
        let projectDirectory = project.basePath
        let projectPath = project.defaultProjectPath

        // validate project dictionary
        do {
            try specLoader.validateProjectDictionaryWarnings()
        } catch {
            warning("\(error)")
        }

        let cacheFilePath = self.cacheFilePath ??
            Path("~/.xcodegen/cache/\(projectSpecPath.absolute().string.md5)").absolute()
        var cacheFile: CacheFile?

        // read cache
        if useCache || self.cacheFilePath != nil {
            do {
                cacheFile = try specLoader.generateCacheFile()
            } catch {
                throw GenerationError.projectSpecParsingError(error)
            }
        }

        let projectExists = XcodeProj.pbxprojPath(projectPath).exists

        // check cache
        if let cacheFile = cacheFile,
            projectExists,
            cacheFilePath.exists {
            do {
                let existingCacheFile: String = try cacheFilePath.read()
                if cacheFile.string == existingCacheFile {
                    info("Project has not changed since cache was written")
                    return
                }
            } catch {
                info("Couldn't load cache at \(cacheFile)")
            }
        }

        // validate project
        do {
            try project.validateMinimumXcodeGenVersion(version)
            try project.validate()
        } catch let error as SpecValidationError {
            throw GenerationError.validationError(error)
        }

        // run pre gen command
        if let command = project.options.preGenCommand {
            try Task.run(bash: command, directory: projectDirectory.absolute().string)
        }

        // generate plists
        info("⚙️  Generating plists...")
        let fileWriter = FileWriter(project: project)
        do {
            try fileWriter.writePlists()
            if onlyPlists {
                return
            }
        } catch {
            throw GenerationError.writingError(error)
        }

        // generate project
        info("⚙️  Generating project...")
        let xcodeProject: XcodeProj
        do {
            let projectGenerator = ProjectGenerator(project: project)
            xcodeProject = try projectGenerator.generateXcodeProject(in: projectDirectory)
        } catch {
            throw GenerationError.generationError(error)
        }

        // write project
        info("⚙️  Writing project...")
        do {
            try fileWriter.writeXcodeProject(xcodeProject, to: projectPath)
            success("Created project at \(projectPath)")
        } catch {
            throw GenerationError.writingError(error)
        }

        // write cache
        if let cacheFile = cacheFile {
            do {
                try cacheFilePath.parent().mkpath()
                try cacheFilePath.write(cacheFile.string)
            } catch {
                info("Failed to write cache: \(error.localizedDescription)")
            }
        }

        // run post gen command
        if let command = project.options.postGenCommand {
            try Task.run(bash: command, directory: projectDirectory.absolute().string)
        }
    }

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
