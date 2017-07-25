import Foundation
import XCTest

func expectError(_ expectedError: Error, closure: () throws -> ()) {
    do {
        try closure()
        XCTFail("Supposed to fail with \"\(expectedError)\"")
    } catch {
        XCTAssert(error.localizedDescription == expectedError.localizedDescription,
                  "Expected error \"\(expectedError.localizedDescription)\" but got \"\(error.localizedDescription)\"")
    }
}
