import PathKit
import ProjectSpec
import Spectre
@testable import XcodeGenKit
import XcodeProj
import XCTest
import Yams
import TestSupport

class SyncedFolderReproductionTests: XCTestCase {

    func testSyncedFolderReproduction() throws {
        describe {
            let directoryPath = Path("TestDirectory")

            func createDirectories(_ directories: String) throws {
                let yaml = try Yams.load(yaml: directories)!

                func getFiles(_ file: Any, path: Path) -> [Path] {
                    if let array = file as? [Any] {
                        return array.flatMap { getFiles($0, path: path) }
                    } else if let string = file as? String {
                        return [path + string]
                    } else if let dictionary = file as? [String: Any] {
                        var array: [Path] = []
                        for (key, value) in dictionary {
                            array += getFiles(value, path: path + key)
                        }
                        return array
                    } else {
                        return []
                    }
                }

                let files = getFiles(yaml, path: directoryPath)
                for file in files {
                    try file.parent().mkpath()
                    try file.write("")
                }
            }

            func removeDirectories() {
                try? directoryPath.delete()
            }

            $0.before {
                removeDirectories()
            }

            $0.after {
                removeDirectories()
            }

            $0.it("excludes .DS_Store and .xcconfig from synced folder membership") {
                let directories = """
                Sources:
                  - a.swift
                  - .DS_Store
                  - config.xcconfig
                  - Subfolder:
                    - nested.xcconfig
                """
                try createDirectories(directories)

                let source = TargetSource(path: "Sources", type: .syncedFolder)
                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [source])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                let syncedFolder = try unwrap(pbxProj.getMainGroup().children.compactMap { $0 as? PBXFileSystemSynchronizedRootGroup }.first)

                let exceptionSets = syncedFolder.exceptions?.compactMap { $0 as? PBXFileSystemSynchronizedBuildFileExceptionSet }
                let exceptionSet = try unwrap(exceptionSets?.first)
                let exceptions = try unwrap(exceptionSet.membershipExceptions)

                try expect(exceptions.contains("config.xcconfig")) == true
                try expect(exceptions.contains("Subfolder/nested.xcconfig")) == true
                try expect(exceptions.contains(".DS_Store")) == true
            }
        }
    }
}
