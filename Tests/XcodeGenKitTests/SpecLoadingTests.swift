import Spectre
import PathKit
import XcodeGenKit
import xcodeproj
import ProjectSpec

func specLoadingTests() {

    @discardableResult
    func getProjectSpec(_ spec: [String: Any]) throws -> ProjectSpec {
        var specDictionary: [String: Any] = ["name": "test"]
        for (key, value) in spec {
            specDictionary[key] = value
        }
        return try ProjectSpec(jsonDictionary: specDictionary)
    }

    func expectProjectSpecError(_ spec: [String: Any], _ expectedError: ProjectSpecError) throws {
        try expectError(expectedError) {
            try getProjectSpec(spec)
        }
    }

    func expectTargetError(_ target: [String: Any], _ expectedError: ProjectSpecError) throws {
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
                "build": ["targets": ["Target": "all"]],
            ]
            let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)
            let target = scheme.build.targets.first!
            try expect(scheme.name) == "Scheme"
            try expect(target.target) == "Target"
            try expect(target.buildTypes) == [.running, .testing, .profiling, .analyzing, .archiving]
        }

        $0.it("parses settings") {
            let spec = try ProjectSpec(path: fixturePath + "settings_test.yml")
            let buildSettings: BuildSettings = ["SETTING": "value"]
            let configSettings: [String: Settings] = ["config1": Settings(buildSettings: ["SETTING1": "value"])]
            let presets = ["preset1"]

            let preset1 = Settings(buildSettings: buildSettings, configSettings: [:], presets: [])
            let preset2 = Settings(buildSettings: .empty, configSettings: configSettings, presets: [])
            let preset3 = Settings(buildSettings: buildSettings, configSettings: configSettings, presets: [])
            let preset4 = Settings(buildSettings: buildSettings, configSettings: [:], presets: [])
            let preset5 = Settings(buildSettings: buildSettings, configSettings: [:], presets: presets)
            let preset6 = Settings(buildSettings: buildSettings, configSettings: configSettings, presets: presets)
            let preset7 = Settings(buildSettings: buildSettings, configSettings: ["config1": Settings(buildSettings: buildSettings, presets: presets)])
            let preset8 = Settings(buildSettings: .empty, configSettings: ["config1": Settings(configSettings: configSettings)])

            try expect(spec.settingPresets.count) == 8
            try expect(spec.settingPresets["preset1"]) == preset1
            try expect(spec.settingPresets["preset2"]) == preset2
            try expect(spec.settingPresets["preset3"]) == preset3
            try expect(spec.settingPresets["preset4"]) == preset4
            try expect(spec.settingPresets["preset5"]) == preset5
            try expect(spec.settingPresets["preset6"]) == preset6
            try expect(spec.settingPresets["preset7"]) == preset7
            try expect(spec.settingPresets["preset8"]) == preset8
        }

        $0.it("parses run scripts") {
            var target = validTarget
            let scripts: [[String: Any]] = [
                ["path": "script.sh"],
                ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file","file2"], "outputFiles": ["file","file2"], "shell": "bin/customshell"],
            ]
            target["prebuildScripts"] = scripts
            target["postbuildScripts"] = scripts

            let expectedScripts = [
                RunScript(script: .path("script.sh")),
                RunScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file","file2"], outputFiles: ["file","file2"], shell: "bin/customshell"),
                ]

            let parsedTarget = try Target(jsonDictionary: target)
            try expect(parsedTarget.prebuildScripts) == expectedScripts
            try expect(parsedTarget.postbuildScripts) == expectedScripts
        }
    }
}
