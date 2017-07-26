import Spectre
import PathKit
import XcodeGenKit
import xcodeproj

let fixturePath = Path(#file).parent().parent().parent() + "Fixtures"

func generate(specPath: Path, projectPath: Path) throws {
    let spec = try Spec(path: specPath)
    let lintedSpec = SpecLinter.lint(spec)
    if lintedSpec.errors.isEmpty {
        let generator = ProjectGenerator(spec: lintedSpec.spec, path: specPath.parent())
        let project = try generator.generateProject()
        try project.write(path: projectPath, override: true)
        _ = try XcodeProj(path: projectPath)
    } else {
        throw failure("Spec has errors:\n\(lintedSpec.errors.map { $0.description}.joined(separator: "\n"))")
    }
}

func fixtureTests() {


    describe("Test Project") {
        $0.it("generates") {
            try generate(specPath: fixturePath + "TestProject/spec.yml", projectPath: fixturePath + "TestProject/GeneratedProject.xcodeproj")
        }
    }
}
