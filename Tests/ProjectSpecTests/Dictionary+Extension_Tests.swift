@testable import ProjectSpec
import XCTest

final class DictionaryExtensionTests: XCTestCase {
    func testRemovingNil_ShouldReturnNewDictionaryWithoutOptionalValues() {
        // Arrange
        let input: [String: Any?] = inputDictionary
        let expected: [String: Any] = outputDictionary
        XCTAssertNotEqual(input as NSDictionary, expected as NSDictionary)

        // Act
        let sut: [String: Any] = input.removingEmptyArraysDictionariesAndNils()

        // Assert
        XCTAssertEqual(sut as NSDictionary, expected as NSDictionary)
    }
}

extension DictionaryExtensionTests {
    var inputDictionary: [String: Any?] {
        let inner1: [String: Any?] = [
            "inner1": "value1",
            "inner2": Optional("value2"),
            "inner3": nil,
            "inner4": Optional([1, 2, 3]),
        ]
        let inner2: [String: Any?] = [
            "inner1": "value1",
            "inner2": Optional("value2"),
            "inner3": inner1,
            "inner4": [1, 2, 3],
        ]
        let inner3: [String: Any?] = [
            "inner1": "value1",
            "inner2": Optional("value2"),
            "inner3": Optional(inner1),
            "inner4": [1, 2, 3],
            "inner5": inner2,
        ]
        let inner4: [String: Any?] = [
            "inner1": inner1,
            "inner2": inner2,
            "inner3": inner3,
            "inner4": Optional("value4"),
            "inner5": nil,
        ]

        let inner6: [String: Any?] = [
            "inner1": "value1",
            "inner2": "value2",
            "inner3": [inner1, inner1, inner1],
        ]

        let input: [String: Any?] = [
            "inner1": "value1",
            "inner2": Optional("value2"),
            "inner3": nil,
            "inner4": inner4,
            "inner5": [],
            "inner6": inner6,
            "inner7": [:],
        ]

        return input
    }

    var outputDictionary: [String: Any] {
        let expected: [String: Any] = [
            "inner1": "value1",
            "inner2": "value2",
            "inner4": [
                "inner1": [
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner4": [1, 2, 3],
                ],
                "inner2": [
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner3": [
                        "inner1": "value1",
                        "inner2": "value2",
                        "inner4": [1, 2, 3],
                    ],
                    "inner4": [1, 2, 3],
                ],
                "inner3": [
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner3": [
                        "inner1": "value1",
                        "inner2": "value2",
                        "inner4": [1, 2, 3],
                    ],
                    "inner4": [1, 2, 3],
                    "inner5": [
                        "inner1": "value1",
                        "inner2": "value2",
                        "inner3": [
                            "inner1": "value1",
                            "inner2": "value2",
                            "inner4": [1, 2, 3],
                        ],
                        "inner4": [1, 2, 3],
                    ],
                ],
                "inner4": "value4",
            ],
            "inner6": [
                "inner1": "value1",
                "inner2": "value2",
                "inner3": [[
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner4": [1, 2, 3],
                ], [
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner4": [1, 2, 3],
                ], [
                    "inner1": "value1",
                    "inner2": "value2",
                    "inner4": [1, 2, 3],
                ]],
            ],
        ]

        return expected
    }
}
