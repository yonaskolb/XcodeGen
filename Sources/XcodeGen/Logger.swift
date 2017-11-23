import Foundation
import Rainbow

struct Logger {

    // MARK: - Properties

    let isQuiet: Bool
    let isColored: Bool

    // MARK: - Initializers

    init(isQuiet: Bool = false, isColored: Bool = true) {
        self.isQuiet = isQuiet
        self.isColored = isColored
    }

    // MARK: - Logging

    func fatal(_ message: String) {
        print(isColored ? message.red : message)
    }

    func info(_ message: String) {
        if isQuiet {
            return
        }

        print(message)
    }

    func success(_ message: String) {
        if isQuiet {
            return
        }

        print(isColored ? message.green : message)
    }
}
