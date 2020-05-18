import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Yams

class MigrateCommand: Command {
    let name: String = "migrate"

    let projectFile = Key<Path>("-p", "--project", description: "The path to the project file")

    let spec = Key<Path>(
        "-s",
        "--spec",
        description: "The path to the project spec file should be generated. Defaults to project.yml"
    )

    func execute() throws {
        guard let file = projectFile.value else {
            return
        }
        let xcodeProj = try XcodeProj(path: file)
        let project = try generateSpec(xcodeProj: xcodeProj, projectDirectory: file.parent())
        let projectDict = project?.toJSONDictionary().removeEmpty()
        let encodedYAML = try Yams.dump(object: projectDict)
        let defaultOutPath = file.parent() + "project.yml"
        let outPath = spec.value ?? defaultOutPath
        try encodedYAML.write(toFile: outPath.string, atomically: true, encoding: .utf8)
    }
}
