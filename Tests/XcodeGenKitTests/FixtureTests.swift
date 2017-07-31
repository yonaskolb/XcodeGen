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
    try project.write(path: projectPath, override: true)
    _ = try XcodeProj(path: projectPath)
}

func fixtureTests() {

    describe("Test Project") {
        $0.it("generates") {
            try generate(specPath: fixturePath + "TestProject/spec.yml", projectPath: fixturePath + "TestProject/GeneratedProject.xcodeproj")
        }
    }
}
