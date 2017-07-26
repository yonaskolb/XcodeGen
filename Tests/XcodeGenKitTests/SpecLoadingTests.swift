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

    func expectSpecError(_ spec: [String: Any], _ expectedError: SpecError) throws {
        try expectError(expectedError) {
            try getSpec(spec)
        }
    }

    func expectTargetError( _ target: [String: Any], _ expectedError: SpecError) throws {
        try expectError(expectedError) {
            _ = try Target(jsonDictionary: target)
        }
    }

    let validTarget: [String: Any] = ["name": "test", "type": "application", "platform": "iOS"]
    let invalid = "invalid"

    describe("Project Spec") {

        $0.it("fails with incorrect platform") {
            var target = validTarget
            target["platform"] = invalid
            try expectTargetError(target, .unknownTargetPlatform(invalid))
        }

        $0.it("fails with incorrect product type") {
            var target = validTarget
            target["type"] = invalid
            try expectTargetError(target, .unknownTargetType(invalid))
        }

        $0.it("fails with invalid dependency") {
            var target = validTarget
            target["dependencies"] = [[invalid: "name"]]
            try expectTargetError(target, .invalidDependency([invalid: "name"]))
        }

        $0.it("parses target dependencies") {
            var target = validTarget
            target["dependencies"] = [
                ["target": "name"],
                ["carthage": "name"],
                ["framework": "path"],
                ]
            let specTarget = try Target(jsonDictionary: target)
            try expect(specTarget.dependencies.count) == 3
            try expect(specTarget.dependencies[0]) == .target("name")
            try expect(specTarget.dependencies[1]) == .carthage("name")
            try expect(specTarget.dependencies[2]) == .framework("path")
        }
    }

}
