@testable import XcodeGenKitTests
import XCTest

XCTMain([
    testCase(GeneratorTests.allTests),
    testCase(SpecLoadingTests.allTests),
    testCase(FixtureTests.allTests),
    testCase(ProjectSpecTests.allTests),
])
