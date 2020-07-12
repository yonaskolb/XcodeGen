import XCTest
import XcodeGenKit
import TestSupport
import XcodeProj
import PathKit
import Yams

class SpecGeneratorTests: XCTestCase {
    func testRemoveEmpty() {
        let arr: [Any] = [[], [1, [2], []], [3]]
        let removed: [Any] = arr.removeEmpty()

        let dict: [String: Any?] = ["e": nil]
        let removed2: [String: Any] = dict.removeEmpty()
        XCTAssertEqual(removed2.count, 0)
        let removed3: [String: Any] = dict.compactMapValues { $0 }
        XCTAssertEqual(removed3.count, 0)
    }

    func testMigrateDependencies() throws {
        let file = fixturePath + "MigrationTestProject/MigrationTestProject.xcodeproj"
        let xcodeProj = try XcodeProj(path: file)
        let project = try generateSpec(xcodeProj: xcodeProj, projectDirectory: file.parent())!
        let target = project.targets.first { $0.name == "MigrationTestProject" }!
        XCTAssertEqual(target.dependencies[0].reference, "ExampleFramework")
        XCTAssertEqual(target.dependencies[0].type, .target)
        XCTAssertEqual(target.dependencies[1].reference, "AVKit.framework")
        XCTAssertEqual(target.dependencies[1].type, .sdk(root: "System/Library/Frameworks"))
    }
}
