import Foundation
import ProjectSpec
import XcodeProj

public class BreakpointGenerator {

    let project: Project

    public init(project: Project) {
        self.project = project
    }

    func generateBreakpointList() throws -> XCBreakpointList {
        let breakpoints = project.breakpoints
        return XCBreakpointList(type: "4", version: "2.0", breakpoints: try breakpoints.map({ try generateBreakpointProxy($0) }))
    }

    private func generateBreakpointProxy(_ breakpoint: Breakpoint) throws -> XCBreakpointList.BreakpointProxy {
        var extensionID: XCBreakpointList.BreakpointProxy.BreakpointExtensionID
        switch breakpoint.extensionID {
            case "file": extensionID = .file
            case "exception": extensionID = .exception
            case "swiftError": extensionID = .swiftError
            case "openGLError": extensionID = .openGLError
            case "symbolic": extensionID = .symbolic
            case "ideConstraintError": extensionID = .ideConstraintError
            case "ideTestFailure": extensionID = .ideTestFailure
            default: throw SpecValidationError.ValidationError.invalidBreakpointExtensionID(breakpoint.extensionID)
        }

        let xcbreakpoint = XCBreakpointList.BreakpointProxy.BreakpointContent(enabled: breakpoint.enabled,
                                                                              ignoreCount: breakpoint.ignoreCount,
                                                                              continueAfterRunningActions: breakpoint.continueAfterRunningActions,
                                                                              filePath: breakpoint.filePath,
                                                                              timestamp: breakpoint.timestamp,
                                                                              startingColumn: breakpoint.startingColumn,
                                                                              endingColumn: breakpoint.endingColumn,
                                                                              startingLine: breakpoint.startingLine,
                                                                              endingLine: breakpoint.endingLine,
                                                                              breakpointStackSelectionBehavior: breakpoint.breakpointStackSelectionBehavior,
                                                                              symbol: breakpoint.symbol,
                                                                              module: breakpoint.module,
                                                                              scope: breakpoint.scope,
                                                                              stopOnStyle: breakpoint.stopOnStyle,
                                                                              actions: try breakpoint.actions.map({ try generateBreakpointActionProxy($0) }),
                                                                              locations: breakpoint.locations.map({ generateBreakpointLocationProxy($0) }))

        return XCBreakpointList.BreakpointProxy(breakpointExtensionID: extensionID, breakpointContent: xcbreakpoint)
    }

    private func generateBreakpointActionProxy(_ breakpointAction: Breakpoint.Action) throws -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy {
        var extensionID: XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionExtensionID
        switch breakpointAction.extensionID {
            case "debuggerCommand": extensionID = .debuggerCommand
            case "log": extensionID = .log
            case "shellCommand": extensionID = .shellCommand
            case "graphicsTrace": extensionID = .graphicsTrace
            case "appleScript": extensionID = .appleScript
            case "sound": extensionID = .sound
            case "openGLError": extensionID = .openGLError
            default: throw SpecValidationError.ValidationError.invalidBreakpointActionExtensionID(breakpointAction.extensionID)
        }

        let xcaction = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionContent(consoleCommand: breakpointAction.consoleCommand,
                                                                                                                        message: breakpointAction.message,
                                                                                                                        conveyanceType: breakpointAction.conveyanceType,
                                                                                                                        command: breakpointAction.command,
                                                                                                                        arguments: breakpointAction.arguments,
                                                                                                                        waitUntilDone: breakpointAction.waitUntilDone,
                                                                                                                        script: breakpointAction.script,
                                                                                                                        soundName: breakpointAction.soundName)

        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy(actionExtensionID: extensionID, actionContent: xcaction)
    }

    private func generateBreakpointLocationProxy(_ breakpointLocation: Breakpoint.Location) -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointLocationProxy {
        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointLocationProxy()
    }
}
