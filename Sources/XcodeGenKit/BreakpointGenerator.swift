import Foundation
import ProjectSpec
import XcodeProj

public class BreakpointGenerator {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    func generateBreakpointList() throws -> XCBreakpointList? {
        let breakpoints = project.breakpoints
        guard !breakpoints.isEmpty else {
            return nil
        }
        return XCBreakpointList(type: "4", version: "2.0", breakpoints: try breakpoints.map({ try generateBreakpointProxy($0) }))
    }

    private func generateBreakpointProxy(_ breakpoint: Breakpoint) throws -> XCBreakpointList.BreakpointProxy {
        let breakpointExtensionID: BreakpointExtensionID
        var filePath: String?
        var line: String?
        var scope: String?
        var stopOnStyle: String?
        var symbol: String?
        var module: String?
        switch breakpoint.type {
        case let .file(path, lineNumber):
            breakpointExtensionID = .file
            filePath = path
            line = String(lineNumber)
        case let .exception(exception):
            breakpointExtensionID = .exception
            scope = exception.scope.rawValue
            stopOnStyle = exception.stopOnStyle.rawValue
        case .swiftError:
            breakpointExtensionID = .swiftError
        case .openGLError:
            breakpointExtensionID = .openGLError
        case let .symbolic(symbolName, moduleName):
            breakpointExtensionID = .symbolic
            symbol = symbolName
            module = moduleName
        case .ideConstraintError:
            breakpointExtensionID = .ideConstraintError
        case .ideTestFailure:
            breakpointExtensionID = .ideTestFailure
        }
        let xcbreakpoint = XCBreakpointList.BreakpointProxy.BreakpointContent(
            enabled: breakpoint.enabled,
            ignoreCount: String(breakpoint.ignoreCount),
            continueAfterRunningActions: breakpoint.continueAfterRunningActions,
            filePath: filePath,
            startingLine: line,
            endingLine: line,
            symbol: symbol,
            module: module,
            scope: scope,
            stopOnStyle: stopOnStyle,
            condition: breakpoint.condition,
            actions: try breakpoint.actions.map { try generateBreakpointActionProxy($0) }
        )

        return XCBreakpointList.BreakpointProxy(
            breakpointExtensionID: breakpointExtensionID,
            breakpointContent: xcbreakpoint
        )
    }

    private func generateBreakpointActionProxy(_ breakpointAction: Breakpoint.Action) throws -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy {
        let actionExtensionID: BreakpointActionExtensionID
        var consoleCommand: String?
        var message: String?
        var conveyanceType: String?
        var command: String?
        var arguments: String?
        var waitUntilDone: Bool?
        var script: String?
        var soundName: String?
        switch breakpointAction {
        case let .debuggerCommand(command):
            actionExtensionID = .debuggerCommand
            consoleCommand = command
        case let .log(log):
            actionExtensionID = .log
            message = log.message
            conveyanceType = log.conveyanceType.rawValue
        case let .shellCommand(commandPath, commandArguments, waitUntilCommandDone):
            actionExtensionID = .shellCommand
            command = commandPath
            arguments = commandArguments
            waitUntilDone = waitUntilCommandDone
        case .graphicsTrace:
            actionExtensionID = .graphicsTrace
        case let .appleScript(appleScript):
            actionExtensionID = .appleScript
            script = appleScript
        case let .sound(sound):
            actionExtensionID = .sound
            soundName = sound.rawValue
        }
        let xcaction = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionContent(
            consoleCommand: consoleCommand,
            message: message,
            conveyanceType: conveyanceType,
            command: command,
            arguments: arguments,
            waitUntilDone: waitUntilDone,
            script: script,
            soundName: soundName
        )

        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy(
            actionExtensionID:  actionExtensionID,
            actionContent: xcaction
        )
    }
}
