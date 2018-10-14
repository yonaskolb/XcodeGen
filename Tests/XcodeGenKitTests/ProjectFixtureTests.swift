import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcodeproj
import XCTest

class ProjectFixtureTests: XCTestCase {

    func testProjectFixture() {
        describe {
            var xcodeProject: XcodeProj?

            $0.it("generates") {
                xcodeProject = try generateXcodeProject(specPath: fixturePath + "TestProject/project.yml")
            }

            $0.it("generates variant group") {
                guard let xcodeProject = xcodeProject else { return }

                func getFileReferences(_ path: String) -> [PBXFileReference] {
                    return xcodeProject.pbxproj.fileReferences.filter { $0.path == path }
                }

                func getVariableGroups(_ name: String?) -> [PBXVariantGroup] {
                    return xcodeProject.pbxproj.variantGroups.filter { $0.name == name }
                }

                let resourceName = "LocalizedStoryboard.storyboard"
                let baseResource = "Base.lproj/LocalizedStoryboard.storyboard"
                let localizedResource = "en.lproj/LocalizedStoryboard.strings"

                guard let variableGroup = getVariableGroups(resourceName).first else { throw failure("Couldn't find the variable group") }

                do {
                    let refs = getFileReferences(baseResource)
                    try expect(refs.count) == 1
                    try expect(variableGroup.children.filter { $0 == refs.first }.count) == 1
                }

                do {
                    let refs = getFileReferences(localizedResource)
                    try expect(refs.count) == 1
                    try expect(variableGroup.children.filter { $0 == refs.first }.count) == 1
                }
            }

            $0.it("generates scheme execution actions") {
                guard let xcodeProject = xcodeProject else { return }

                let frameworkScheme = xcodeProject.sharedData?.schemes.first { $0.name == "Framework" }
                try expect(frameworkScheme?.buildAction?.preActions.first?.scriptText) == "echo Starting Framework Build"
                try expect(frameworkScheme?.buildAction?.preActions.first?.title) == "Run Script"
                try expect(frameworkScheme?.buildAction?.preActions.first?.environmentBuildable?.blueprintName) == "Framework_iOS"
                try expect(frameworkScheme?.buildAction?.preActions.first?.environmentBuildable?.buildableName) == "Framework.framework"
            }
        }
    }
}

fileprivate func generateXcodeProject(specPath: Path, file: String = #file, line: Int = #line) throws -> XcodeProj {
    let project = try Project(path: specPath)
    let generator = ProjectGenerator(project: project)
    let xcodeProject = try generator.generateXcodeProject()
    try xcodeProject.write(path: project.projectPath, override: true)

    return xcodeProject
}
