import XCTest
import PathKit
import XcodeGenKit
import xcodeproj

class SpecLoadingTests: XCTestCase {

    @discardableResult
    func getSpec(_ spec: [String: Any]) throws -> Spec {
        var specDictionary: [String: Any] = ["name": "test"]
        for (key, value) in spec {
            specDictionary[key] = value
        }
        return try Spec(jsonDictionary: specDictionary)
    }

    func expectSpecFailure(_ expectedError: SpecError, _ spec: [String: Any]) {
        expectError(expectedError) {
            try getSpec(spec)
        }
    }

    func testIncorrectTargetPlatform() throws {
        expectSpecFailure(.unknownTargetPlatform("invalid"), ["targets": [["name": "test", "type": "application", "platform": "invalid"]]])
    }

    func testIncorrectTargetProductType() throws {
        expectSpecFailure(.unknownTargetType("invalid"), ["targets": [["name": "test", "type": "invalid", "platform": "iOS"]]])
    }

    static var allTests = [
        ("testIncorrectTargetPlatform", testIncorrectTargetPlatform),
        ("testIncorrectTargetProductType", testIncorrectTargetProductType),
        ]
}
