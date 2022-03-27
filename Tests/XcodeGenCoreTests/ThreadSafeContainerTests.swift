//
//  ThreadSafeContainerTests.swift
//  
//
//  Created by Vladislav Lisianskii on 27.03.2022.
//

import XCTest
@testable import XcodeGenCore

final class ThreadSafeContainerTests: XCTestCase {

    private var threadSafeDictionary = ThreadSafeContainer([String: Int]())

    func testSimultaneousWriteOrder() {
        let group = DispatchGroup()

        for index in (0..<10) {
            group.enter()
            DispatchQueue.global().async {
                self.threadSafeDictionary.value["\(index)"] = index
                group.leave()
            }
        }

        group.notify(queue: .main, execute: {
            XCTAssertEqual(
                self.threadSafeDictionary,
                ThreadSafeContainer(["0": 0, "1": 1, "2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9])
            )
        })
    }
}
