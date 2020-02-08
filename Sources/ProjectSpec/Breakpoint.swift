import Foundation
import XcodeProj
import JSONUtilities

public typealias BreakpointActionExtensionID = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
public typealias BreakpointExtensionID = XCBreakpointList.BreakpointProxy.BreakpointExtensionID

public struct Breakpoint: Equatable {

    public enum BreakpointType: Equatable {

        public struct Exception: Equatable {

            public enum Scope: String, Equatable {
                case all = "0"
                case objectiveC = "1"
                case cpp = "2"
            }

            public enum StopOnStyle: String, Equatable {
                case `throw` = "0"
                case `catch` = "1"
            }

            public var scope: Scope
            public var stopOnStyle: StopOnStyle

            public init(scope: Breakpoint.BreakpointType.Exception.Scope = .objectiveC,
                        stopOnStyle: Breakpoint.BreakpointType.Exception.StopOnStyle = .throw) {
                self.scope = scope
                self.stopOnStyle = stopOnStyle
            }
        }
        case file(path: String, line: Int)
        case exception(Exception)
        case swiftError
        case openGLError
        case symbolic(symbol: String?, module: String?)
        case ideConstraintError
        case ideTestFailure
    }

    public enum Action: Equatable {

        public struct Log: Equatable {

            public enum ConveyanceType: String, Equatable {
                case console = "0"
                case speak = "1"
            }

            public var message: String?
            public var conveyanceType: ConveyanceType

            public init(message: String? = nil, conveyanceType: Breakpoint.Action.Log.ConveyanceType = .console) {
                self.message = message
                self.conveyanceType = conveyanceType
            }
        }

        public enum Sound: String, Equatable {
            case basso = "Basso"
            case blow = "Blow"
            case bottle = "Bottle"
            case frog = "Frog"
            case funk = "Funk"
            case glass = "Glass"
            case hero = "Hero"
            case morse = "Morse"
            case ping = "Ping"
            case pop = "Pop"
            case purr = "Purr"
            case sosumi = "Sosumi"
            case submarine = "Submarine"
            case tink = "Tink"
        }

        case debuggerCommand(String?)
        case log(Log)
        case shellCommand(path: String?, arguments: String?, waitUntilDone: Bool = false)
        case graphicsTrace
        case appleScript(String?)
        case sound(Sound)
        case openGLError
    }

    public var type: BreakpointType
    public var enabled: Bool
    public var ignoreCount: Int
    public var continueAfterRunningActions: Bool
    public var timestamp: String?
    public var breakpointStackSelectionBehavior: String?
    public var condition: String?
    public var actions: [Breakpoint.Action]

    public init(type: BreakpointType,
                enabled: Bool = true,
                ignoreCount: Int = 0,
                continueAfterRunningActions: Bool = false,
                filePath: String? = nil,
                timestamp: String? = nil,
                line: Int? = nil,
                breakpointStackSelectionBehavior: String? = nil,
                condition: String? = nil,
                actions: [Breakpoint.Action] = []) {
        self.type = type
        self.enabled = enabled
        self.ignoreCount = ignoreCount
        self.continueAfterRunningActions = continueAfterRunningActions
        self.timestamp = timestamp
        self.breakpointStackSelectionBehavior = breakpointStackSelectionBehavior
        self.condition = condition
        self.actions = actions
    }
}

extension Breakpoint.BreakpointType.Exception.Scope {

    public init(string: String) throws {
        let string = string.lowercased()
        switch string {
        case "all":
            self = .all
        case "objective-c":
            self = .objectiveC
        case "c++":
            self = .cpp
        default:
            throw SpecParsingError.unknownBreakpointScope(string)
        }
    }
}

extension Breakpoint.BreakpointType.Exception.StopOnStyle {

    public init(string: String) throws {
        let string = string.lowercased()
        switch string {
        case "throw":
            self = .throw
        case "catch":
            self = .catch
        default:
            throw SpecParsingError.unknownBreakpointStopOnStyle(string)
        }
    }
}

extension Breakpoint.Action.Log.ConveyanceType {

    init(string: String) throws {
        let string = string.lowercased()
        switch string {
        case "console":
            self = .console
        case "speak":
            self = .speak
        default:
            throw SpecParsingError.unknownBreakpointActionConveyanceType(string)
        }
    }
}

extension Breakpoint.Action.Sound {

    init(name: String) throws {
        guard let sound = Self.init(rawValue: name) else {
            throw SpecParsingError.unknownBreakpointActionSoundName(name)
        }
        self = sound
    }
}

extension Breakpoint.Action: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let idString: String = try jsonDictionary.json(atKeyPath: "type")
        let id = try BreakpointActionExtensionID(string: idString)
        switch id {
        case .debuggerCommand:
            let command: String? = jsonDictionary.json(atKeyPath: "command")
            self = .debuggerCommand(command)
        case .log:
            let message: String? = jsonDictionary.json(atKeyPath: "message")
            let conveyanceType: Log.ConveyanceType
            if jsonDictionary["conveyanceType"] != nil {
                let conveyanceTypeString: String = try jsonDictionary.json(atKeyPath: "conveyanceType")
                conveyanceType = try .init(string: conveyanceTypeString)
            } else {
                conveyanceType = .console
            }
            self = .log(.init(message: message, conveyanceType: conveyanceType))
        case .shellCommand:
            let path: String? = jsonDictionary.json(atKeyPath: "path")
            let arguments: String? = jsonDictionary.json(atKeyPath: "arguments")
            let waitUntilDone = jsonDictionary.json(atKeyPath: "waitUntilDone") ?? false
            self = .shellCommand(path: path, arguments: arguments, waitUntilDone: waitUntilDone)
        case .graphicsTrace:
            self = .graphicsTrace
        case .appleScript:
            let script: String? = jsonDictionary.json(atKeyPath: "script")
            self = .appleScript(script)
        case .sound:
            let sound: Sound
            if jsonDictionary["sound"] != nil {
                let name: String = try jsonDictionary.json(atKeyPath: "sound")
                sound = try .init(name: name)
            } else {
                sound = .basso
            }
            self = .sound(sound)
        case .openGLError:
            self = .openGLError
        }
    }
}

extension Breakpoint: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let idString: String = try jsonDictionary.json(atKeyPath: "type")
        let id = try BreakpointExtensionID(string: idString)
        switch id {
        case .file:
            let path: String = try jsonDictionary.json(atKeyPath: "path")
            let line: Int = try jsonDictionary.json(atKeyPath: "line")
            type = .file(path: path, line: line)
        case .exception:
            let scope: BreakpointType.Exception.Scope
            if jsonDictionary["scope"] != nil {
                let scopeString: String = try jsonDictionary.json(atKeyPath: "scope")
                scope = try .init(string: scopeString)
            } else {
                scope = .objectiveC
            }
            let stopOnStyle: BreakpointType.Exception.StopOnStyle
            if jsonDictionary["stopOnStyle"] != nil {
                let stopOnStyleString: String = try jsonDictionary.json(atKeyPath: "stopOnStyle")
                stopOnStyle = try .init(string: stopOnStyleString)
            } else {
                stopOnStyle = .throw
            }
            type = .exception(.init(scope: scope, stopOnStyle: stopOnStyle))
        case .swiftError:
            type = .swiftError
        case .openGLError:
            type = .openGLError
        case .symbolic:
            let symbol: String? = jsonDictionary.json(atKeyPath: "symbol")
            let module: String? = jsonDictionary.json(atKeyPath: "module")
            type = .symbolic(symbol: symbol, module: module)
        case .ideConstraintError:
            type = .ideConstraintError
        case .ideTestFailure:
            type = .ideTestFailure
        }
        enabled = jsonDictionary.json(atKeyPath: "enabled") ?? true
        ignoreCount = jsonDictionary.json(atKeyPath: "ignoreCount") ?? 0
        continueAfterRunningActions = jsonDictionary.json(atKeyPath: "continueAfterRunningActions") ?? false
        timestamp = jsonDictionary.json(atKeyPath: "timestamp")
        breakpointStackSelectionBehavior = jsonDictionary.json(atKeyPath: "breakpointStackSelectionBehavior")
        condition = jsonDictionary.json(atKeyPath: "condition")
        if jsonDictionary["actions"] != nil {
            actions = try jsonDictionary.json(atKeyPath: "actions", invalidItemBehaviour: .fail)
        } else {
            actions = []
        }
    }
}
