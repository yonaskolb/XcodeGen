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
        let lineString = breakpoint.line.flatMap(String.init)
        let xcbreakpoint = XCBreakpointList.BreakpointProxy.BreakpointContent(enabled: breakpoint.enabled,
                                                                              ignoreCount: String(breakpoint.ignoreCount),
                                                                              continueAfterRunningActions: breakpoint.continueAfterRunningActions,
                                                                              filePath: breakpoint.filePath,
                                                                              timestamp: breakpoint.timestamp,
                                                                              startingLine: lineString,
                                                                              endingLine: lineString,
                                                                              breakpointStackSelectionBehavior: breakpoint.breakpointStackSelectionBehavior,
                                                                              symbol: breakpoint.symbol,
                                                                              module: breakpoint.module,
                                                                              scope: breakpoint.scope?.rawValue,
                                                                              stopOnStyle: breakpoint.stopOnStyle?.rawValue,
                                                                              actions: try breakpoint.actions.map({ try generateBreakpointActionProxy($0) }))

        return XCBreakpointList.BreakpointProxy(breakpointExtensionID: breakpoint.type,
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
                                                                                                                        soundName: breakpointAction.soundName)

        return XCBreakpointList.BreakpointProxy.BreakpointContent.BreakpointActionProxy(actionExtensionID:  breakpointAction.type,
                                                                                        actionContent: xcaction)
    }
}
