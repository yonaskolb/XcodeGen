import Foundation
import XcodeProj
import JSONUtilities

public typealias BreakpointActionType = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
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

    public struct Action: Equatable {

        public enum ConveyanceType: String, Equatable {
            case console = "0"
            case speak = "1"

            init?(_ text: String) {
                let text = text.lowercased()
                switch text {
                case "console":
                    self = .console
                case "speak":
                    self = .speak
                default:
                    return nil
                }
            }
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

        public var type: BreakpointActionType
        public var consoleCommand: String?
        public var message: String?
        public var conveyanceType: ConveyanceType?
        public var command: String?
        public var arguments: String?
        public var waitUntilDone: Bool?
        public var script: String?
        public var soundName: SoundName?

        public init(type: BreakpointActionType,
                    consoleCommand: String? = nil,
                    message: String? = nil,
                    conveyanceType: ConveyanceType? = nil,
                    command: String? = nil,
                    arguments: String? = nil,
                    waitUntilDone: Bool? = nil,
                    script: String? = nil,
                    soundName: SoundName? = nil) {
            self.type = type
            self.consoleCommand = consoleCommand
            self.message = message
            self.conveyanceType = conveyanceType
            self.command = command
            self.arguments = arguments
            self.waitUntilDone = waitUntilDone
            self.script = script
            self.soundName = soundName
        }
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

extension Breakpoint.Action: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = BreakpointActionType(string: typeString) {
            self.type = type
        } else {
            throw SpecParsingError.unknownBreakpointActionType(typeString)
        }
        consoleCommand = jsonDictionary.json(atKeyPath: "consoleCommand")
        message = jsonDictionary.json(atKeyPath: "message")
        if type == .log {
            if jsonDictionary["conveyanceType"] != nil {
                let conveyanceTypeString: String = try jsonDictionary.json(atKeyPath: "conveyanceType")
                if let conveyanceType = ConveyanceType(conveyanceTypeString) {
                    self.conveyanceType = conveyanceType
                } else {
                    throw SpecParsingError.unknownBreakpointActionConveyanceType(conveyanceTypeString)
                }
            } else {
                conveyanceType = .console
            }
        }
        if type == .shellCommand {
            command = jsonDictionary.json(atKeyPath: "command")
            arguments = jsonDictionary.json(atKeyPath: "arguments")
            waitUntilDone = jsonDictionary.json(atKeyPath: "waitUntilDone") ?? false
        }
        script = jsonDictionary.json(atKeyPath: "script")
        if type == .sound {
            if jsonDictionary["soundName"] != nil {
                let soundNameString: String = try jsonDictionary.json(atKeyPath: "soundName")
                if let soundName = SoundName(rawValue: soundNameString) {
                    self.soundName = soundName
                } else {
                    throw SpecParsingError.unknownBreakpointActionSoundName(soundNameString)
                }
            } else {
                soundName = .basso
            }
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
