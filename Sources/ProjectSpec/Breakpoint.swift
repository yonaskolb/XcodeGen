import Foundation
import XcodeProj
import JSONUtilities

public typealias BreakpointActionExtensionID = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
public typealias BreakpointExtensionID = XCBreakpointList.BreakpointProxy.BreakpointExtensionID

public struct Breakpoint: Equatable {

    public enum BreakpointType: Equatable {
        case file(path: String, line: Int)
        case exception(scope: Scope = .objectiveC, stopOnStyle: StopOnStyle = .throw)
        case swiftError
        case openGLError
        case symbolic(symbol: String?, module: String?)
        case ideConstraintError
        case ideTestFailure
    }

    public enum Scope: String, Equatable {
        case all = "0"
        case objectiveC = "1"
        case cpp = "2"
    }

    public enum StopOnStyle: String, Equatable {
        case `throw` = "0"
        case `catch` = "1"
    }

    public enum Action: Equatable {

        public enum ConveyanceType: String, Equatable {
            case console = "0"
            case speak = "1"
        }

        public enum SoundName: String, Equatable {
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
        case log(message: String?, conveyanceType: ConveyanceType = .console)
        case shellCommand(path: String?, arguments: String?, waitUntilDone: Bool = false)
        case graphicsTrace
        case appleScript(String?)
        case sound(name: SoundName)
    }

    public var type: BreakpointType
    public var enabled: Bool
    public var ignoreCount: Int
    public var continueAfterRunningActions: Bool
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
        self.condition = condition
        self.actions = actions
    }
}

extension Breakpoint.Scope {

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

extension Breakpoint.StopOnStyle {

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

extension Breakpoint.Action.ConveyanceType {

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

extension Breakpoint.Action.SoundName {

    init(string: String) throws {
        guard let soundName = Self.init(rawValue: string) else {
            throw SpecParsingError.unknownBreakpointActionSoundName(string)
        }
        self = soundName
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
            let conveyanceType: ConveyanceType
            if jsonDictionary["conveyanceType"] != nil {
                let conveyanceTypeString: String = try jsonDictionary.json(atKeyPath: "conveyanceType")
                conveyanceType = try ConveyanceType(string: conveyanceTypeString)
            } else {
                conveyanceType = .console
            }
            self = .log(message: message, conveyanceType: conveyanceType)
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
            let name: SoundName
            if jsonDictionary["name"] != nil {
                let soundNameString: String = try jsonDictionary.json(atKeyPath: "name")
                name = try SoundName(string: soundNameString)
            } else {
                name = .basso
            }
            self = .sound(name: name)
        case .openGLError:
            throw SpecParsingError.unknownBreakpointActionType(idString)
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
            let scope: Scope
            if jsonDictionary["scope"] != nil {
                let scopeString: String = try jsonDictionary.json(atKeyPath: "scope")
                scope = try Scope(string: scopeString)
            } else {
                scope = .objectiveC
            }
            let stopOnStyle: StopOnStyle
            if jsonDictionary["stopOnStyle"] != nil {
                let stopOnStyleString: String = try jsonDictionary.json(atKeyPath: "stopOnStyle")
                stopOnStyle = try StopOnStyle(string: stopOnStyleString)
            } else {
                stopOnStyle = .throw
            }
            type = .exception(scope: scope, stopOnStyle: stopOnStyle)
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
        condition = jsonDictionary.json(atKeyPath: "condition")
        if jsonDictionary["actions"] != nil {
            actions = try jsonDictionary.json(atKeyPath: "actions", invalidItemBehaviour: .fail)
        } else {
            actions = []
        }
    }
}
