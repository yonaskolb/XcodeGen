import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XcodeProj
import XCTest
import TestSupport
import Yams

class FixtureTests: XCTestCase {

    func testProjectFixture() {

        describe {
            $0.it("generates Test Fixture") {
                try generateFixture(specPath: fixturePath + "TestProject/AnotherProject/project.yml")
                try generateFixture(specPath: fixturePath + "TestProject/project.yml")
            }
            $0.it("generates Carthage Fixture") {
                try generateFixture(specPath: fixturePath + "CarthageProject/project.yml")
            }
            $0.it("generates SPM Fixture") {
                try generateFixture(specPath: fixturePath + "SPM/project.yml")
            }
        }
    }
}

func generateFixture(specPath: Path, file: StaticString = #file, line: UInt = #line) throws {

    // generate xcode project
    let project: Project
    do {
        project = try Project(path: specPath)
        try generateXcodeProject(project: project)
    } catch {
        XCTFail("Could not generate XcodeProj: \(error)", file: file, line: line)
        return
    }

    // generate project spec

    let xcodeProjectPath = specPath.parent() + "\(project.name).xcodeproj"
    let generatedSpecPath = specPath.parent() + "\(specPath.lastComponentWithoutExtension)-generated.yml"
    do {
        try generateProjectSpec(xcodeProjectPath: xcodeProjectPath, specPath: generatedSpecPath)
    } catch {
        XCTFail("Could not generate Project: \(error)", file: file, line: line)
        return
    }

    // parse generated project spec
    do {
        _ = try Project(path: generatedSpecPath)
    } catch {
        XCTFail("Could not parse generated Project: \(error)", file: file, line: line)
        return
    }
}

func generateProjectSpec(xcodeProjectPath: Path, specPath: Path) throws {
    let xcodeProj = try XcodeProj(path: xcodeProjectPath)
    let generatedProject = try generateSpec(xcodeProj: xcodeProj, projectDirectory: specPath.parent())
    let projectDict = generatedProject.toJSONDictionary().removeEmpty()
    var encodedYAML = try Yams.dump(object: projectDict)
    encodedYAML = "# Generated from \(try xcodeProjectPath.relativePath(from: specPath.parent()))\n\(encodedYAML)"
    try encodedYAML.write(toFile: specPath.string, atomically: true, encoding: .utf8)
}

func generateXcodeProject(project: Project) throws {
    let generator = ProjectGenerator(project: project)
    let writer = FileWriter(project: project)
    let xcodeProject = try generator.generateXcodeProject()
    try writer.writeXcodeProject(xcodeProject)
    try writer.writePlists()
}

