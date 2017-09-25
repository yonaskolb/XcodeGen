import Spectre
import PathKit
import XcodeGenKit
import xcodeproj
import ProjectSpec

let fixturePath = Path(#file).parent().parent().parent() + "Fixtures"

func generate(specPath: Path, projectPath: Path) throws {
    let spec = try ProjectSpec(path: specPath)
    let generator = ProjectGenerator(spec: spec, path: specPath.parent())
    let project = try generator.generateProject()
    let oldProject = try XcodeProj(path: projectPath)
    try project.write(path: projectPath, override: true)

    let newProject = try XcodeProj(path: projectPath)
    if newProject != oldProject {
        throw failure("\(projectPath.string) has changed. If change is legitimate commit the change and run test again")
    }
}

func fixtureTests() {

    describe("Test Project") {
        $0.it("generates") {
            try generate(specPath: fixturePath + "TestProject/spec.yml", projectPath: fixturePath + "TestProject/GeneratedProject.xcodeproj")
        }
    }
}
