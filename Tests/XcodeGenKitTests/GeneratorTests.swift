import XCTest
import XcodeGenKit
import xcodeproj
import PathKit

class GeneratorTests: XCTestCase {

    func getProject(_ spec: Spec) throws -> XcodeProj {
        let lintedSpec = SpecLinter.lint(spec)
        let generator = ProjectGenerator(spec: lintedSpec.spec, path: Path(""))
        return try generator.generate()
    }

    func testGeneratorGeneratesDefaultConfigs() throws {
        let project = try getProject(Spec(name: "test"))
        XCTAssert(project.pbxproj.objects.buildConfigurations.count == 2)
    }

    static var allTests = [
        ("testGeneratorGeneratesDefaultConfigs", testGeneratorGeneratesDefaultConfigs),
        ]
}
