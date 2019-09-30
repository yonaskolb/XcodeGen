import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XcodeProj
import XCTest

class ProjectFixtureTests: XCTestCase {

    func testProjectFixture() {
        describe {
            $0.it("generates fixtures") {
                try generateXcodeProject(specPath: fixturePath + "TestProject/project.yml")
                try generateXcodeProject(specPath: fixturePath + "CarthageProject/project.yml")
                try generateXcodeProject(specPath: fixturePath + "SPM/project.yml")
            }
        }
    }
}

private func generateXcodeProject(specPath: Path, file: String = #file, line: Int = #line) throws {
    let project = try Project(path: specPath)
    let generator = ProjectGenerator(project: project)
    let writer = FileWriter(project: project)
    let xcodeProject = try generator.generateXcodeProject()
    try writer.writeXcodeProject(xcodeProject)
    try writer.writePlists()
}
