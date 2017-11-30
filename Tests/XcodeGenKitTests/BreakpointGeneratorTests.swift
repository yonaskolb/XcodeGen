import ProjectSpec
import Spectre
import XCTest

class BreakpointGeneratorTests: XCTestCase {

    func testBreakpoints() {
        describe {

            $0.it("generates breakpoint") {
                let breakpoint = Breakpoint(extensionID: "exception")
                let project = Project(basePath: "", name: "test", targets: [], breakpoints: [breakpoint])
                let xcodeProject = try project.generateXcodeProject()
                guard let xcbreakpoint = xcodeProject.sharedData?.breakpoints?.breakpoints.first else { throw failure("Breakpoint not found") }
                try expect(xcbreakpoint.breakpointExtensionID.rawValue) == "Xcode.Breakpoint.ExceptionBreakpoint"
            }
        }
    }
}
