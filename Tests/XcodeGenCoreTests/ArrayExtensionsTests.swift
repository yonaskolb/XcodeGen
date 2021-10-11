import XCTest
@testable import XcodeGenCore

class ArrayExtensionsTests: XCTestCase {
    
    func testSearchingForFirstIndex() {
        let array = SortedArray([1, 2, 3, 4 ,5])
        XCTAssertEqual(array.firstIndex(where: { $0 > 2 }), 2)
    }
    
    func testIndexCannotBeFound() {
        let array = SortedArray([1, 2, 3, 4, 5])
        XCTAssertEqual(array.firstIndex(where: { $0 > 10 }), nil)
    }

    func testEmptyArray() {
        let array = SortedArray([Int]())
        XCTAssertEqual(array.firstIndex(where: { $0 > 0 }), nil)
    }
    
    func testSearchingReturnsFirstIndexWhenMultipleElementsHaveSameValue() {
        let array = SortedArray([1, 2, 3, 3 ,3])
        XCTAssertEqual(array.firstIndex(where: { $0 == 3 }), 2)
    }
}


class SortedArrayTests: XCTestCase {
    
    func testSortingOnInitialization() {
        let array = [1, 5, 4, 2]
        let sortedArray = SortedArray(array)
        XCTAssertEqual([1, 2, 4, 5], sortedArray.value)
    }
    
    func testEmpty() {
        XCTAssertEqual([Int](), SortedArray([Int]()).value)
    }

}
