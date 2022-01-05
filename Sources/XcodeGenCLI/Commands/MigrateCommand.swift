import Foundation
import PathKit
import ProjectSpec
import SwiftCLI
import XcodeGenKit
import XcodeProj
import Yams

class MigrateCommand: Command {
    let name: String = "migrate"
    let shortDescription: String = "Migrates an Xcode project to an XcodeGen project spec"

    @Param
    var projectPath: Path

    @Key("-s", "--spec", description: "The path to the generated project spec. Defaults to project.yml in the same directory as the project")
    var spec: Path?

    func execute() throws {
        let xcodeProj = try XcodeProj(path: projectPath)
        let project = try generateSpec(xcodeProj: xcodeProj, projectDirectory: projectPath.parent())
        let projectDict = project.toJSONDictionary().removeEmpty()
        let encodedYAML = try Yams.dump(object: projectDict)
        let defaultOutPath = projectPath.parent() + "project.yml"
        let outPath = spec ?? defaultOutPath
        try encodedYAML.write(toFile: outPath.string, atomically: true, encoding: .utf8)
    }
}
