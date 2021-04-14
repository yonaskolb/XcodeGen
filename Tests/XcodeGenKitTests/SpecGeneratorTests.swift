import XCTest
import XcodeGenKit
import TestSupport
import XcodeProj
import PathKit
import Yams
import ProjectSpec

class SpecGeneratorTests: XCTestCase {
    var project: Project!
    var target: Target!

    override func setUpWithError() throws {
        let file = fixturePath + "MigrationTestProject/MigrationTestProject.xcodeproj"
        let xcodeProj = try XcodeProj(path: file)
        project = try generateSpec(xcodeProj: xcodeProj, projectDirectory: file.parent())
        target = project.targets.first { $0.name == "MigrationTestProject" }!

        let projectDict = project.toJSONDictionary().removeEmpty()
        let encodedYAML = try Yams.dump(object: projectDict)
        print(encodedYAML)
    }

    func testRemoveEmpty() {
        let arr = [[], [1, [2], []], [3]]
        let removed = arr.removeEmpty()
        XCTAssertEqual(removed.count, 2)

        let dict: [String: Any?] = ["e": nil]
        let removed2: [String: Any?] = dict.removeEmpty()
        XCTAssertEqual(removed2.count, 0)
        let removed3: [String: Any] = dict.compactMapValues { $0 }
        XCTAssertEqual(removed3.count, 0)
    }

    func testMigrateDependencies() throws {
        XCTAssertEqual(target.dependencies[0].reference, "ExampleFramework")
        XCTAssertEqual(target.dependencies[0].type, .target)
        XCTAssertEqual(target.dependencies[1].reference, "AVKit.framework")
        XCTAssertEqual(target.dependencies[1].type, .sdk(root: "System/Library/Frameworks"))
    }

    func testBuildScript() throws {
        XCTAssertEqual(target.preBuildScripts[0].name, "Pre Build Script")
        XCTAssertEqual(target.postCompileScripts[0].name, "Post Compile Script")
        XCTAssertEqual(target.postBuildScripts[0].name, "Post Build Script")
    }

    func testScheme() throws {
        XCTAssertEqual(project.schemes.count, 3)
    }
    
    func testCocoapodsDeintegration() throws {
        for target in project.targets {
            XCTAssertTrue(target.buildScripts.allSatisfy { !($0.name ?? "").starts(with: "[CP]") })
            XCTAssertTrue(target.dependencies.allSatisfy { !$0.reference.starts(with: "libPods") })
            XCTAssertTrue(target.dependencies.allSatisfy { !$0.reference.starts(with: "Pods_") })
        }
    }
}
