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
            var targetDictionary = validTarget
            targetDictionary["dependencies"] = [
                ["target": "name"],
                ["carthage": "name"],
                ["framework": "path"],
                ]
            let target = try Target(jsonDictionary: targetDictionary)
            try expect(target.dependencies.count) == 3
            try expect(target.dependencies[0]) == .target("name")
            try expect(target.dependencies[1]) == .carthage("name")
            try expect(target.dependencies[2]) == .framework("path")
        }

        $0.it("parses schemes") {
            let schemeDictionary: [String: Any] = [
                "build": ["targets": ["Target": "all"]]
            ]
            let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)
            let target = scheme.build.targets.first!
            try expect(scheme.name) == "Scheme"
            try expect(target.target) == "Target"
            try expect(target.buildTypes) == [.running, .testing, .profiling, .analyzing, .archiving]
        }
    }

}
