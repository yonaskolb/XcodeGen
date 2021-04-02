import Foundation
import PathKit
import ProjectSpec
import XcodeGenKit
import XcodeProj
import XCTest

class GeneratedPerformanceTests: XCTestCase {

    let basePath = Path.temporary + "XcodeGenPeformanceTests"

    func testLoading() throws {
        let project = try Project.testProject(basePath: basePath)
        let specPath = basePath + "project.yaml"
        try dumpYamlDictionary(project.toJSONDictionary(), path: specPath)

        measure {
            let spec = try! SpecFile(path: specPath)
            _ = spec.resolvedDictionary(variables: ProcessInfo.processInfo.environment)
        }
    }

    func testGeneration() throws {
        let project = try Project.testProject(basePath: basePath)
        measure {
            let expectation = XCTestExpectation(description: "Project generation expectation")
            let generator = ProjectGenerator(project: project)
            try! generator.generateXcodeProject { _ in
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }

    func testWriting() throws {
        let project = try Project.testProject(basePath: basePath)
        let generator = ProjectGenerator(project: project)
        let expectation = XCTestExpectation(description: "Project generation expectation")
        var xcodeProject: XcodeProj!
        try generator.generateXcodeProject() { (generatedXcodeProj) in
            xcodeProject = generatedXcodeProj
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
        measure {
            xcodeProject.pbxproj.invalidateUUIDs()
            try! xcodeProject.write(path: project.defaultProjectPath)
        }
    }
}

let fixturePath = Path(#file).parent().parent() + "Fixtures"

class FixturePerformanceTests: XCTestCase {

    let specPath = fixturePath + "TestProject/project.yml"

    func testFixtureDecoding() throws {
        measure {
            _ = try! Project(path: specPath)
        }
    }

    func testCacheFileGeneration() throws {
        let specLoader = SpecLoader(version: "1.2")
        _ = try specLoader.loadProject(path: specPath)

        measure {
            _ = try! specLoader.generateCacheFile()
        }
    }

    func testFixtureGeneration() throws {
        let project = try Project(path: specPath)
        measure {
            let generator = ProjectGenerator(project: project)
            let expectation = XCTestExpectation(description: "Project generation expectation")
            DispatchQueue.global(qos: .userInitiated).async {
                _ = try! generator.generateXcodeProject() { _ in
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testFixtureWriting() throws {
        let project = try Project(path: specPath)
        let generator = ProjectGenerator(project: project)
        let expectation = XCTestExpectation(description: "Project generation expectation")
        var xcodeProject: XcodeProj!
        try! generator.generateXcodeProject() { (generatedXcodeProj) in
            xcodeProject = generatedXcodeProj
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)
        measure {
            xcodeProject.pbxproj.invalidateUUIDs()
            try! xcodeProject.write(path: project.defaultProjectPath)
        }
    }
}
