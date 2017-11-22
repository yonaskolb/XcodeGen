import Foundation
import Rainbow

/// Mechanism for logging informational, success, and fatal messages.
struct Logger {

    // MARK: - Properties

    /// Should informational and success messages be suppressed
    let isQuiet: Bool

    /// Should the output be colored
    let isColored: Bool

    // MARK: - Initializers

    /// Initialize a logger
    ///
    /// - parameter isQuiet: should informational and success messages be suppressed
    /// - parameter isColored: should the output be colored
    init(isQuiet: Bool = false, isColored: Bool = true) {
        self.isQuiet = isQuiet
        self.isColored = isColored
    }

    // MARK: - Logging

    /// Log a fatal message and exit with status code 1
    ///
    /// - parameter message: the message to log
    func fatal(_ message: String) {
        print(isColored ? message.red : message)
    }

    /// Log an informational message
    ///
    /// - parameter message: the message to log
    func info(_ message: String) {
        if isQuiet {
            return
        }

        print(message)
    }

    /// Log a success message and exit with status code 0
    ///
    /// - parameter message: the message to log
    func success(_ message: String) {
        if isQuiet {
            return
        }

        print(isColored ? message.green : message)
    }
}
