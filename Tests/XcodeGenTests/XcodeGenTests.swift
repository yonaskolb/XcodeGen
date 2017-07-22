import XCTest
import PathKit
import XcodeGenKit

class XcodeGenTests: XCTestCase {

    let fixturePath = Path(#file).parent().parent().parent() + "Fixtures"

    func testGeneration() throws {
        let specPath = fixturePath + "TestProject/spec.yml"
        let spec = try Spec(path: specPath)
        let lintedSpec = SpecLinter.lint(spec)
        if lintedSpec.errors.isEmpty {
            let generator = ProjectGenerator(spec: lintedSpec.spec, path: fixturePath + "TestProject/spec.xcodeproj")
            let project = try generator.generate()
            try project.write(override: true)
        } else {
            XCTFail("Spec has errors:\n\(lintedSpec.errors.map { $0.description}.joined(separator: "\n"))")
        }
    }

    static var allTests = [
        ("testGeneration", testGeneration),
        ]
}
