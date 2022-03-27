//
//  AtomicTests.swift
//  
//
//  Created by Vladislav Lisianskii on 27.03.2022.
//

import XCTest
@testable import XcodeGenCore

final class AtomicTests: XCTestCase {

    @Atomic private var atomicDictionary = [String: Int]()

    func testSimultaneousWriteOrder() {
        let group = DispatchGroup()

        for index in (0..<100) {
            group.enter()
            DispatchQueue.global().async {
                self.$atomicDictionary.with { atomicDictionary in
                    atomicDictionary["\(index)"] = index
                }
                group.leave()
            }
        }

        group.notify(queue: .main, execute: {
            var expectedValue = [String: Int]()
            for index in (0..<100) {
                expectedValue["\(index)"] = index
            }
            XCTAssertEqual(
                self.atomicDictionary,
                expectedValue
            )
        })
    }
}
