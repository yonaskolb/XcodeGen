import Foundation
import SwiftCLI

class CommandRouter: Router {

    let defaultCommand: Command

    init(defaultCommand: Command) {
        self.defaultCommand = defaultCommand
    }

    func parse(commandGroup: CommandGroup, arguments: ArgumentList) throws -> (CommandPath, OptionRegistry) {
        if !arguments.hasNext() {
            arguments.manipulate { _ in
                [defaultCommand.name]
            }
        }
        return try DefaultRouter().parse(commandGroup: commandGroup, arguments: arguments)
    }
}
