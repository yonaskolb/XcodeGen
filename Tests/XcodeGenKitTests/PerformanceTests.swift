import XcodeGenKit
import xcproj
import Foundation
import XCTest
import ProjectSpec
import PathKit

class GeneratedPerformanceTests: XCTestCase {

    let basePath = Path.temporary + "XcodeGenPeformanceTests"

    func testGeneration() throws {
        let project = try Project.testProject(basePath: basePath)
        self.measure {
            let generator = ProjectGenerator(project: project)
            _ = try! generator.generateXcodeProject()
        }
    }

    func testWriting() throws {
        let project = try Project.testProject(basePath: basePath)
        let generator = ProjectGenerator(project: project)
        let xcodeProject = try generator.generateXcodeProject()
        self.measure {
            try! xcodeProject.write(path: project.projectPath)
        }
    }
}

class FixturePerformanceTests: XCTestCase {

    let specPath = fixturePath + "TestProject/project.yml"

    func testFixtureDecoding() throws {
        self.measure {
            _ = try! Project(path: specPath)
        }
    }

    func testFixtureGeneration() throws {
        let project = try Project(path: specPath)
        self.measure {
            let generator = ProjectGenerator(project: project)
            _ = try! generator.generateXcodeProject()
        }
    }

    func testFixtureWriting() throws {
        let project = try Project(path: specPath)
        let generator = ProjectGenerator(project: project)
        let xcodeProject = try generator.generateXcodeProject()
        self.measure {
            try! xcodeProject.write(path: project.projectPath)
        }
    }
}
