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

        $0.it("parses settings") {
            let spec = try Spec(path: fixturePath + "settings_test.yml")
            try expect(spec.settingPresets.count) == 3
            let preset1 = SettingPreset(settings: ["SETTING 1": "value 1"], settingPresets: ["preset2"])
            let preset2 = SettingPreset(settings: ["SETTING 2": "value 2"])
            let preset3 = SettingPreset(settings: Settings(buildSettings: ["SETTING 9": "value 9"], configSettings: ["config1": ["SETTING 8": "value 8"]]), settingPresets: ["preset2"])

            let config1 = Config(name: "config1", type: .debug, settings: BuildSettings(dictionary: ["SETTING 3": "value 3"]), settingPresets: ["preset1"])
            let config2 = Config(name: "config2", type: .release, settings: BuildSettings(dictionary: ["SETTING 4": "value 4"]), settingPresets: ["preset2"])
            try expect(spec.settingPresets["preset1"]) == preset1
            try expect(spec.settingPresets["preset2"]) == preset2
            try expect(spec.settingPresets["preset3"]) == preset3

            try expect(spec.getConfig("config1")) == config1
            try expect(spec.getConfig("config2")) == config2
        }
    }

}
