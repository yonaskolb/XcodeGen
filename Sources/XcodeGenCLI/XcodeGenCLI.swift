import Foundation
import ProjectSpec
import SwiftCLI

public class XcodeGenCLI {
    private class Manipulator: ArgumentListManipulator {
        let commandName: String

        init(commandName: String) {
            self.commandName = commandName
        }

        func manipulate(arguments: ArgumentList) {
            if !arguments.hasNext() || arguments.nextIsOption() {
                arguments.manipulate { existing in
                    return [commandName] + existing
                }
            }
        }
    }

    let cli: CLI

    public init(version: Version) {
        let generateCommand = GenerateCommand(version: version)

        cli = CLI(
            name: "xcodegen",
            version: version.string,
            description: "Generates Xcode projects",
            commands: [generateCommand]
        )
        let manipulator = Manipulator(commandName: generateCommand.name)
        cli.argumentListManipulators.insert(manipulator, at: 0)
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
