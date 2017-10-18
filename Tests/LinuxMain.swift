import XCTest
@testable import XcodeGenKitTests

XCTMain([
    testCase(GeneratorTests.allTests),
    testCase(SpecLoadingTests.allTests),
    testCase(FixtureTests.allTests),
    testCase(ProjectSpecTests.allTests),
])
