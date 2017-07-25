import Spectre
import XcodeGenKit
import xcodeproj
import PathKit

func generatorTests() {

    func getProject(_ spec: Spec) throws -> XcodeProj {
        let lintedSpec = SpecLinter.lint(spec)
        let generator = ProjectGenerator(spec: lintedSpec.spec, path: Path(""))
        return try generator.generate()
    }

    describe("Generator") {

        $0.it("provide defaults") {
            let project = try getProject(Spec(name: "test"))
            try expect(project.pbxproj.objects.buildConfigurations.count) == 2

        }
    }
}

