import ProjectSpec
import Spectre
import TestSupport
import XCTest

class BreakpointGeneratorTests: XCTestCase {

    func testBreakpoints() {
        describe {

            $0.it("generates breakpoint") {
                let breakpoint = Breakpoint(type: .exception)
                let project = Project(basePath: "", name: "test", targets: [], breakpoints: [breakpoint])
                let xcodeProject = try project.generateXcodeProject()
                let xcbreakpoint = try unwrap(xcodeProject.sharedData?.breakpoints?.breakpoints.first)
                try expect(xcbreakpoint.breakpointExtensionID.rawValue) == "Xcode.Breakpoint.ExceptionBreakpoint"
            }
        }
    }
}
