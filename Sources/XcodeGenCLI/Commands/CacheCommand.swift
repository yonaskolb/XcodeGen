import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Version

class CacheCommand: ProjectCommand {

    @Key("--cache-path", description: "Where the cache file will be loaded from and save to. Defaults to ~/.xcodegen/cache/{SPEC_PATH_HASH}")
    var cacheFilePath: Path?

    init(version: Version) {
        super.init(version: version,
                   name: "cache",
                   shortDescription: "Write the project cache")
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {

        let cacheFilePath = self.cacheFilePath ?? Path("~/.xcodegen/cache/\(projectSpecPath.absolute().string.md5)").absolute()

        var cacheFile: CacheFile?

        // generate cache
        do {
            cacheFile = try specLoader.generateCacheFile()
        } catch {
            throw GenerationError.projectSpecParsingError(error)
        }

        // write cache
        if let cacheFile = cacheFile {
            do {
                try cacheFilePath.parent().mkpath()
                try cacheFilePath.write(cacheFile.string)
                success("Wrote cache to \(cacheFilePath)")
            } catch {
                info("Failed to write cache: \(error.localizedDescription)")
            }
        }
    }
}
