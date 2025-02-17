import Foundation
import ProjectSpec
import SwiftCLI
import Version

public class XcodeGenCLI {
    let cli: CLI

    public init(version: Version) {
        let generateCommand = GenerateCommand(version: version)

        cli = CLI(
            name: "xcodegen",
            version: version.description,
            description: "Generates Xcode projects",
            commands: [
                generateCommand,
                CacheCommand(version: version),
                DumpCommand(version: version),
            ]
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
