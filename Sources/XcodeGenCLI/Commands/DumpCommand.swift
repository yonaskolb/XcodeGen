import Foundation
import SwiftCLI
import PathKit
import ProjectSpec
import Yams

class DumpCommand: ProjectCommand {

    private let dumpType = Key<DumpType>(
        "--type",
        "-t",
        description: """
        The type of dump to output. Either \(DumpType.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: ", ")). Defaults to \(DumpType.defaultValue.rawValue). The "parsed" types parse the project into swift and then back again.
        """
    )

    private let file = Key<Path>(
        "--file",
        "-f",
        description: "The path of a file to write to. If not supplied will output to stdout"
    )

    init(version: Version) {
        super.init(version: version,
                   name: "dump",
                   shortDescription: "Dumps the resolved project spec to stdout or a file")
    }

    override func execute(specLoader: SpecLoader, projectSpecPath: Path, project: Project) throws {
        let type = dumpType.value ?? .defaultValue

        let output: String
        switch type {
        case .swiftDump:
            var string = ""
            dump(project, to: &string)
            output = string
        case .json:
            let data = try JSONSerialization.data(withJSONObject: specLoader.projectDictionary!, options: .prettyPrinted)
            output = String(data: data, encoding: .utf8)!
        case .yaml:
            output = try Yams.dump(object: specLoader.projectDictionary!)
        case .parsedJSON:
            let data = try JSONSerialization.data(withJSONObject: project.toJSONDictionary(), options: .prettyPrinted)
            output = String(data: data, encoding: .utf8)!
        case .parsedYaml:
            output = try Yams.dump(object: project.toJSONDictionary())
        case .summary:
            output = project.debugDescription
        }

        if let file = file.value {
            try file.parent().mkpath()
            try file.write(output)
        } else {
            stdout.print(output)
        }
    }
}

private enum DumpType: String, ConvertibleFromString, CaseIterable {
    case swiftDump = "swift-dump"
    case json
    case yaml
    case parsedJSON = "parsed-json"
    case parsedYaml = "parsed-yaml"
    case summary

    static var defaultValue: DumpType { .yaml }
}
