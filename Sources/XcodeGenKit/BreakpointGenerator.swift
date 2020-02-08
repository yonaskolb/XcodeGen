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
        let xcbreakpoint = XCBreakpointList.BreakpointProxy.BreakpointContent(enabled: breakpoint.enabled,
                                                                              ignoreCount: String(breakpoint.ignoreCount),
                                                                              continueAfterRunningActions: breakpoint.continueAfterRunningActions,
                                                                              filePath: filePath,
                                                                              timestamp: breakpoint.timestamp,
                                                                              startingLine: line,
                                                                              endingLine: line,
                                                                              breakpointStackSelectionBehavior: breakpoint.breakpointStackSelectionBehavior,
                                                                              symbol: symbol,
                                                                              module: module,
                                                                              scope: scope,
                                                                              stopOnStyle: stopOnStyle,
                                                                              condition: breakpoint.condition,
                                                                              actions: try breakpoint.actions.map({ try generateBreakpointActionProxy($0) }))

        return XCBreakpointList.BreakpointProxy(breakpointExtensionID: breakpointExtensionID,
                                                breakpointContent: xcbreakpoint)
    }

    private func generateBreakpointActionProxy(_ breakpointAction: Breakpoint.Action) throws -> XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy {
        let xcaction = XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy.ActionContent(consoleCommand: breakpointAction.consoleCommand,
                                                                                                                        message: breakpointAction.message,
                                                                                                                        conveyanceType: breakpointAction.conveyanceType?.rawValue,
                                                                                                                        command: breakpointAction.command,
                                                                                                                        arguments: breakpointAction.arguments,
                                                                                                                        waitUntilDone: breakpointAction.waitUntilDone,
                                                                                                                        script: breakpointAction.script,
                                                                                                                        soundName: breakpointAction.soundName?.rawValue)

        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy(actionExtensionID:  breakpointAction.type,
                                                                                        actionContent: xcaction)
    }
}
