import XCTest
import XcodeGenKit
import TestSupport
import XcodeProj
import PathKit
import Yams
import ProjectSpec
import Spectre

class SpecGeneratorTests: XCTestCase {
    var project: Project!

    override func setUpWithError() throws {
        let file = fixturePath + "MigrationTestProject/MigrationTestProject.xcodeproj"
        let xcodeProj = try XcodeProj(path: file)
        project = try generateSpec(xcodeProj: xcodeProj, projectDirectory: file.parent())
    }
    
    // Output spec as a string for debugging
    private func stringify() throws -> String {
        let projectDict = project.toJSONDictionary().removeEmpty()
        return try Yams.dump(object: projectDict)
    }
    
    func testGeneration() {
        describe {
            let project = self.project!
            let target = project.targets.first { $0.name == "MigrationTestProject" }!
            
            $0.it("generates targets") {
                try expect(project.targets[0].name) == "MigrationTestProject"
                try expect(project.targets[0].type) == .application
                
                try expect(project.targets[1].name) == "MigrationTestProjectTests"
                try expect(project.targets[1].type) == .unitTestBundle
                
                try expect(project.targets[2].name) == "ExampleFramework"
                try expect(project.targets[2].type) == .framework
                
                try expect(project.targets[3].name) == "ExampleFrameworkTests"
                try expect(project.targets[3].type) == .unitTestBundle
            }
                
            $0.it("generates dependencies") {
                try expect(target.dependencies[0].reference) == "ExampleFramework"
                try expect(target.dependencies[0].type) == .target
                try expect(target.dependencies[1].reference) == "AVKit.framework"
                try expect(target.dependencies[1].type) == .sdk(root: "System/Library/Frameworks")
            }
            
            $0.it("generates build scripts") {
                try expect(target.preBuildScripts[0].name) == "Pre Build Script"
                try expect(target.postCompileScripts[0].name) == "Post Compile Script"
                try expect(target.postBuildScripts[0].name) == "Post Build Script"
            }
            
            $0.it("generates schemes") {
                try expect (project.schemes.count) == 3
            }
            
            $0.it("check scheme names") {
                try expect(project.schemes[0].name) == "ExampleFramework"
                try expect(project.schemes[1].name) == "ExampleScheme"
                try expect(project.schemes[2].name) == "MigrationTestProject"
            }
            
            $0.it("check scheme test targets") {
                try expect(project.schemes[2].test?.targets.count) == 4
                try expect(project.schemes[2].test?.targets[0].name) == "MigrationTestProjectTests"
                try expect(project.schemes[2].test?.targets[1].name) == "ExampleFrameworkTests"
                try expect(project.schemes[2].test?.targets[2].name) == "Tests"
                try expect(project.schemes[2].test?.targets[3].name) == "spm-projectTests"
                //try expect(project.schemes[2].test?.targets[3].targetReference) == "spm-projectTests"
            }
            
            $0.it("deintegrates Cocoapods") {
                for target in project.targets {
                    try expect(target.buildScripts.allSatisfy { !($0.name ?? "").starts(with: "[CP]") }).to.beTrue()
                    try expect(target.dependencies.allSatisfy { !$0.reference.starts(with: "libPods") }).to.beTrue()
                    try expect(target.dependencies.allSatisfy { !$0.reference.starts(with: "Pods_") }).to.beTrue()
                }
            }
            
            $0.it("deintegrates Carthage") {
                for target in project.targets {
                    try expect(target.buildScripts.allSatisfy {
                        if case let .script(text) = $0.script {
                            return !text.contains("carthage copy-frameworks")
                        }
                        return true
                    }).to.beTrue()
                }
                try expect(target.dependencies.contains {
                    if case .carthage = $0.type {
                        return $0.reference == "Attributed"
                    }
                    return false
                }).to.beTrue()
            }
        }
    }

    func testRemoveEmpty() {
        describe {
            $0.it("removes empty arrays from array") {
                let arr = [[], [1], [], [2, 3]]
                XCTAssertEqual(arr.removeEmpty(), [[1], [2, 3]])
            }

            $0.it("removes nils from array") {
                let arr = [nil, 1, nil, 2, 3]
                XCTAssertEqual(arr.removeEmpty(), [1, 2, 3])
            }

            $0.it("removes nils and empty arrays from array") {
                let arr = [nil, [1], nil, [2], []]
                XCTAssertEqual(arr.removeEmpty(), [[1], [2]])
            }

            $0.it("removes nils and empty arrays from nested array") {
                let arr: [[[Int?]?]] = [[[1, nil], nil, []]]
                XCTAssertEqual(arr.removeEmpty(), [[[1]]])
            }

            $0.it("removes empty dictionaries from array") {
                let dict = [["foo": 1], [:], ["bar": 2]]
                XCTAssertEqual(dict.removeEmpty(), [["foo": 1], ["bar": 2]])
            }

            $0.it("removes nils from dictionary") {
                let dict = ["foo": nil, "bar": 1]
                let b = dict.removeEmpty()
                XCTAssertEqual(b, ["bar": 1])
            }

            $0.it("removes empty dictionaries from dictionary") {
                let dict = ["foo": [:], "bar": ["x": 1]]
                let b = dict.removeEmpty()
                XCTAssertEqual(b, ["bar": ["x": 1]])
            }
        }
    }
}
