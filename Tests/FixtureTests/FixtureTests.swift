import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XcodeProj
import XCTest
import TestSupport

class FixtureTests: XCTestCase {

    func testProjectFixture() throws {
        try skipIfNecessary()
        describe {
            $0.it("generates Test Project") {
                try generateXcodeProject(specPath: fixturePath + "TestProject/AnotherProject/project.yml")
                try generateXcodeProject(specPath: fixturePath + "TestProject/project.yml")
            }
            $0.it("generates Carthage Project") {
                try generateXcodeProject(specPath: fixturePath + "CarthageProject/project.yml")
            }
            $0.it("generates SPM Project") {
                try generateXcodeProject(specPath: fixturePath + "SPM/project.yml")
            }
        }
    }
}

private func generateXcodeProject(specPath: Path, file: String = #file, line: Int = #line) throws {
    let project = try Project(path: specPath)
    let generator = ProjectGenerator(project: project)
    let writer = FileWriter(project: project)
    let xcodeProject = try generator.generateXcodeProject(userName: "someUser")
    try writer.writeXcodeProject(xcodeProject)
    try writer.writePlists()
}
