import Foundation
import SwiftCLI

class CommandRouter: Router {

    let defaultCommand: Command

    init(defaultCommand: Command) {
        self.defaultCommand = defaultCommand
    }

    func parse(commandGroup: CommandGroup, arguments: ArgumentList) throws -> (CommandPath, OptionRegistry) {
        if !arguments.hasNext() || arguments.nextIsOption() {
            arguments.manipulate { existing in
                [defaultCommand.name] + existing
            }
        }
        return try DefaultRouter().parse(commandGroup: commandGroup, arguments: arguments)
    }
}
