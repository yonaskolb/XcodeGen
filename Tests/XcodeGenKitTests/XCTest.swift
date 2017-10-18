import Foundation
import XCTest

class XCodeGenKitTests: XCTestCase {

    func testXcodeGenKit() {
        projectGeneratorTests()
        specLoadingTests()
        fixtureTests()
        projectSpecTests()
    }
}
