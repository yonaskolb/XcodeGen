import Spectre
import PathKit
import XcodeGenKit
import xcodeproj

func specLoadingTests() {

    @discardableResult
    func getSpec(_ spec: [String: Any]) throws -> Spec {
        var specDictionary: [String: Any] = ["name": "test"]
        for (key, value) in spec {
            specDictionary[key] = value
        }
        return try Spec(jsonDictionary: specDictionary)
    }

    func expectSpecFailure(_ expectedError: SpecError, _ spec: [String: Any]) throws {
        try expectError(expectedError) {
            try getSpec(spec)
        }
    }

    let validTarget: [String: Any] = ["name": "test", "type": "application", "platform": "iOS"]
    let invalidName = "invalid"

    describe("The project spec") {

        $0.it("fails with incorrect platform") {
            var target = validTarget
            target["platform"] = invalidName
            try expectSpecFailure(.unknownTargetPlatform("invalid"), ["targets": [target]])
        }

        $0.it("fails with incorrect product type") {
            var target = validTarget
            target["type"] = invalidName
            try expectSpecFailure(.unknownTargetType("invalid"), ["targets": [target]])
        }

        $0.it("fails with invalid target dependency") {
            var target = validTarget
            target["dependencies"] = [["invalid": "target"]]
            try expectSpecFailure(.invalidDependency(["invalid": "target"]), ["targets": [target]])
        }
    }

}
