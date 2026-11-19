import Framework
import XCTest

final class AppTests: XCTestCase {

    func testGreeting() {
        XCTAssertFalse(Greeting.text.isEmpty)
    }
}
