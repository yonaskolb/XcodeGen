import Foundation
import ProjectSpec
import SwiftCLI

public class XcodeGenCLI {
    let cli: CLI

    public init(version: Version) {
        let generateCommand = GenerateCommand(version: version)
        let specGenerationCommand = GenerateSpecCommand()

        cli = CLI(
            name: "xcodegen",
            version: version.string,
            description: "Generates Xcode projects",
            commands: [generateCommand, specGenerationCommand]
        )
        cli.parser.routeBehavior = .searchWithFallback(generateCommand)
    }

    public func execute(arguments: [String]? = nil) {
        let status: Int32
        if let arguments = arguments {
            status = cli.go(with: arguments)
        } else {
            status = cli.go()
        }
        exit(status)
    }
}
