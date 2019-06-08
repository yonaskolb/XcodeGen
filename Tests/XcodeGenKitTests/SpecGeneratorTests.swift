import XCTest
import XcodeGenKit

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
}
