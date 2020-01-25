import Foundation
import XcodeProj
import JSONUtilities

public typealias BreakpointActionType = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
public typealias BreakpointType = XCBreakpointList.BreakpointProxy.BreakpointExtensionID

public struct Breakpoint: Equatable {

    public enum Scope: String, Equatable {
        case all = "0"
        case objectiveC = "1"
        case cpp = "2"

        init?(_ text: String) {
            let text = text.lowercased()
            switch text {
            case "all":
                self = .all
            case "objective-c":
                self = .objectiveC
            case "c++":
                self = .cpp
            default:
                return nil
            }
        }
    }

    public enum StopOnStyle: String, Equatable {
        case `throw` = "0"
        case `catch` = "1"

        init?(_ text: String) {
            let text = text.lowercased()
            switch text {
            case "throw":
                self = .throw
            case "catch":
                self = .catch
            default:
                return nil
            }
        }
    }

    public struct Action: Equatable {

        public var type: BreakpointActionType
        public var consoleCommand: String?
        public var message: String?
        public var conveyanceType: String?
        public var command: String?
        public var arguments: String?
        public var waitUntilDone: Bool?
        public var script: String?
        public var soundName: String?

        public init(type: BreakpointActionType,
                    consoleCommand: String? = nil,
                    message: String? = nil,
                    conveyanceType: String? = nil,
                    command: String? = nil,
                    arguments: String? = nil,
                    waitUntilDone: Bool? = nil,
                    script: String? = nil,
                    soundName: String? = nil) {
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
    public var filePath: String?
    public var timestamp: String?
    public var startingColumn: Int?
    public var endingColumn: Int?
    public var startingLine: Int?
    public var endingLine: Int?
    public var breakpointStackSelectionBehavior: String?
    public var symbol: String?
    public var module: String?
    public var scope: Scope?
    public var stopOnStyle: StopOnStyle?
    public var condition: String?
    public var actions: [Breakpoint.Action]

    public init(type: BreakpointType,
                enabled: Bool = true,
                ignoreCount: Int = 0,
                continueAfterRunningActions: Bool = false,
                filePath: String? = nil,
                timestamp: String? = nil,
                startingColumn: Int? = nil,
                endingColumn: Int? = nil,
                startingLine: Int? = nil,
                endingLine: Int? = nil,
                breakpointStackSelectionBehavior: String? = nil,
                symbol: String? = nil,
                module: String? = nil,
                scope: Scope? = nil,
                stopOnStyle: StopOnStyle? = nil,
                condition: String? = nil,
                actions: [Breakpoint.Action] = []) {
        self.type = type
        self.enabled = enabled
        self.ignoreCount = ignoreCount
        self.continueAfterRunningActions = continueAfterRunningActions
        self.filePath = filePath
        self.timestamp = timestamp
        self.startingColumn = startingColumn
        self.endingColumn = endingColumn
        self.startingLine = startingLine
        self.endingLine = endingLine
        self.breakpointStackSelectionBehavior = breakpointStackSelectionBehavior
        self.symbol = symbol
        self.module = module
        self.scope = scope
        self.stopOnStyle = stopOnStyle
        self.condition = condition
        self.actions = actions
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
        conveyanceType = jsonDictionary.json(atKeyPath: "conveyanceType")
        command = jsonDictionary.json(atKeyPath: "command")
        arguments = jsonDictionary.json(atKeyPath: "arguments")
        waitUntilDone = jsonDictionary.json(atKeyPath: "waitUntilDone")
        script = jsonDictionary.json(atKeyPath: "script")
        soundName = jsonDictionary.json(atKeyPath: "soundName")
    }
}

extension Breakpoint: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = BreakpointType(string: typeString) {
            self.type = type
        } else {
            throw SpecParsingError.unknownBreakpointType(typeString)
        }
        enabled = jsonDictionary.json(atKeyPath: "enabled") ?? true
        ignoreCount = jsonDictionary.json(atKeyPath: "ignoreCount") ?? 0
        continueAfterRunningActions = jsonDictionary.json(atKeyPath: "continueAfterRunningActions") ?? false
        filePath = jsonDictionary.json(atKeyPath: "filePath")
        timestamp = jsonDictionary.json(atKeyPath: "timestamp")
        startingColumn = jsonDictionary.json(atKeyPath: "startingColumn")
        endingColumn = jsonDictionary.json(atKeyPath: "endingColumn")
        startingLine = jsonDictionary.json(atKeyPath: "startingLine")
        endingLine = jsonDictionary.json(atKeyPath: "endingLine")
        breakpointStackSelectionBehavior = jsonDictionary.json(atKeyPath: "breakpointStackSelectionBehavior")
        symbol = jsonDictionary.json(atKeyPath: "symbol")
        module = jsonDictionary.json(atKeyPath: "module")
        if type == .exception {
            if jsonDictionary["scope"] != nil {
                let scopeString: String = try jsonDictionary.json(atKeyPath: "scope")
                if let scope = Scope(scopeString) {
                    self.scope = scope
                } else {
                    throw SpecParsingError.unknownBreakpointScope(scopeString)
                }
            } else {
                scope = .objectiveC
            }
            if jsonDictionary["stopOnStyle"] != nil {
                let stopOnStyleString: String = try jsonDictionary.json(atKeyPath: "stopOnStyle")
                if let stopOnStyle = StopOnStyle(stopOnStyleString) {
                    self.stopOnStyle = stopOnStyle
                } else {
                    throw SpecParsingError.unknownBreakpointStopOnStyle(stopOnStyleString)
                }
            } else {
                stopOnStyle = .throw
            }
        }
        condition = jsonDictionary.json(atKeyPath: "condition")
        if jsonDictionary["actions"] != nil {
            actions = try jsonDictionary.json(atKeyPath: "actions", invalidItemBehaviour: .fail)
        } else {
            actions = []
        }
    }
}
