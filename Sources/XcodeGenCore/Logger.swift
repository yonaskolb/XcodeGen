import Foundation


public protocol LogRenderer: AnyObject {
    func debug(_ string: String)
    func info(_ string: String, wasSuccess: Bool)
    func warning(_ string: String)
    func error(_ string: String)
}

public class Logger {

    public enum LogLevel: Int {
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
    }

    public static let shared = Logger(.info)

    public var logLevel: Logger.LogLevel
    public weak var delegate: LogRenderer?

    public init(_ logLevel: Logger.LogLevel) {
        self.logLevel = logLevel
    }

    public func debug(_ string: String) {
        if self.logLevel.rawValue <= LogLevel.debug.rawValue {
            delegate?.debug(string)
        }
    }

    public func info(_ string: String) {
        if self.logLevel.rawValue <= LogLevel.info.rawValue {
            delegate?.info(string, wasSuccess: false)
        }
    }

    public func warning(_ string: String) {
        if self.logLevel.rawValue <= LogLevel.warning.rawValue {
            delegate?.warning(string)
        }
    }

    public func error(_ string: String) {
        if self.logLevel.rawValue <= LogLevel.error.rawValue {
            delegate?.error(string)
        }
    }

    public func success(_ string: String) {
        if self.logLevel.rawValue <= LogLevel.info.rawValue {
            delegate?.info(string, wasSuccess: true)
        }
    }
}
