import Foundation
import xcproj
import JSONUtilities

public struct Breakpoint: Equatable {

    public struct Action: Equatable {

        public var extensionID: String
        public var consoleCommand: String?
        public var message: String?
        public var conveyanceType: String?
        public var command: String?
        public var arguments: String?
        public var waitUntilDone: Bool?
        public var script: String?
        public var soundName: String?

        public init(extensionID: String,
                    consoleCommand: String? = nil,
                    message: String? = nil,
                    conveyanceType: String? = nil,
                    command: String? = nil,
                    arguments: String? = nil,
                    waitUntilDone: Bool? = nil,
                    script: String? = nil,
                    soundName: String? = nil) {
            self.extensionID = extensionID
            self.consoleCommand = consoleCommand
            self.message = message
            self.conveyanceType = conveyanceType
            self.command = command
            self.arguments = arguments
            self.waitUntilDone = waitUntilDone
            self.script = script
            self.soundName = soundName
        }

        public static func ==(lhs: Breakpoint.Action, rhs: Breakpoint.Action) -> Bool {
            return lhs.extensionID == rhs.extensionID
        }
    }

    public struct Location: Equatable {

        public init() {}

        public static func ==(lhs: Breakpoint.Location, rhs: Breakpoint.Location) -> Bool {
            return true
        }
    }

    public var extensionID: String
    public var enabled: Bool
    public var ignoreCount: String
    public var continueAfterRunningActions: Bool
    public var filePath: String?
    public var timestamp: String?
    public var startingColumn: String?
    public var endingColumn: String?
    public var startingLine: String?
    public var endingLine: String?
    public var breakpointStackSelectionBehavior: String?
    public var symbol: String?
    public var module: String?
    public var scope: String?
    public var stopOnStyle: String?
    public var condition: String?
    public var actions: [Breakpoint.Action]
    public var locations: [Breakpoint.Location]

    public init(extensionID: String,
                enabled: Bool = true,
                ignoreCount: String = "0",
                continueAfterRunningActions: Bool = false,
                filePath: String? = nil,
                timestamp: String? = nil,
                startingColumn: String? = nil,
                endingColumn: String? = nil,
                startingLine: String? = nil,
                endingLine: String? = nil,
                breakpointStackSelectionBehavior: String? = nil,
                symbol: String? = nil,
                module: String? = nil,
                scope: String? = nil,
                stopOnStyle: String? = nil,
                condition: String? = nil,
                actions: [Breakpoint.Action] = [],
                locations: [Breakpoint.Location] = []) {
        self.extensionID = extensionID
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
        self.locations = locations
    }

    public static func == (lhs: Breakpoint, rhs: Breakpoint) -> Bool {
        return lhs.extensionID == rhs.extensionID &&
        lhs.enabled == rhs.enabled &&
        lhs.ignoreCount == rhs.ignoreCount &&
        lhs.continueAfterRunningActions == rhs.continueAfterRunningActions
    }
}

extension Breakpoint.Action: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {
        extensionID = try jsonDictionary.json(atKeyPath: "extensionID")
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

extension Breakpoint.Location: JSONObjectConvertible {
    public init(jsonDictionary: JSONDictionary) throws {}
}

extension Breakpoint: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        extensionID = try jsonDictionary.json(atKeyPath: "extensionID")
        enabled = jsonDictionary.json(atKeyPath: "enabled") ?? true
        ignoreCount = jsonDictionary.json(atKeyPath: "ignoreCount") ?? "0"
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
        scope = jsonDictionary.json(atKeyPath: "scope")
        stopOnStyle = jsonDictionary.json(atKeyPath: "stopOnStyle")
        condition = jsonDictionary.json(atKeyPath: "condition")
        actions = jsonDictionary.json(atKeyPath: "actions") ?? []
        locations = jsonDictionary.json(atKeyPath: "locations") ?? []
    }
}
