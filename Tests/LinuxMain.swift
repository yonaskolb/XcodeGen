import XCTest

import CoreTests
import FixtureTests
import PerformanceTests
import ProjectSpecTests
import XcodeGenKitTests

var tests = [XCTestCaseEntry]()
tests += CoreTests.__allTests()
tests += FixtureTests.__allTests()
tests += PerformanceTests.__allTests()
tests += ProjectSpecTests.__allTests()
tests += XcodeGenKitTests.__allTests()

XCTMain(tests)

