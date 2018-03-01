import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcproj
import Foundation

func specLoadingTests() {

    @discardableResult
    func getProjectSpec(_ spec: [String: Any]) throws -> ProjectSpec {
        var specDictionary: [String: Any] = ["name": "test"]
        for (key, value) in spec {
            specDictionary[key] = value
        }
        return try ProjectSpec(basePath: "", jsonDictionary: specDictionary)
    }

    func expectProjectSpecError(_ spec: [String: Any], _ expectedError: SpecParsingError) throws {
        try expectError(expectedError) {
            try getProjectSpec(spec)
        }
    }

    func expectTargetError(_ target: [String: Any], _ expectedError: SpecParsingError) throws {
        try expectError(expectedError) {
            _ = try Target(name: "test", jsonDictionary: target)
        }
    }

    let validTarget: [String: Any] = ["type": "application", "platform": "iOS"]
    let invalid = "invalid"

    describe("Spec Loader") {
        $0.it("merges includes") {
            let path = fixturePath + "include_test.yml"
            let spec = try ProjectSpec(path: path)

            try expect(spec.name) == "NewName"
            try expect(spec.settingGroups) == [
                "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3"]),
                "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
            ]
            try expect(spec.targets) == [
                Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"]),
                Target(name: "NewTarget", type: .application, platform: .iOS),
            ]
        }

        $0.it("parses yaml types") {
            let path = fixturePath + "yaml.yml"
            let dictionary = try loadYamlDictionary(path: path)
            let expectedDictionary: [String: Any] = [
                "true": true,
                "false": false,
                "yes": "YES",
                "no": "NO",
                "yesQuote": "YES",
                "noQuote": "NO",
                "int": 1,
                "intQuote": 1,
                "float": 3.2,
                "string": "hello",
                "stringQuote": "hello",
                "space": " ",
                "empty": "",
                "emptyQuote": "",
                "emptyDictionary": [String: Any](),
                "arrayLiteral": [1,2],
                "arrayList": [1,2],
            ]

            if !(dictionary as NSDictionary).isEqual(expectedDictionary) {
                throw failure("parsed yaml types don't match")
            }
        }
    }

    describe("Spec Loader JSON") {
        $0.it("merges includes") {
            let path = fixturePath + "include_test.json"
            let spec = try ProjectSpec(path: path)

            try expect(spec.name) == "NewName"
            try expect(spec.settingGroups) == [
                "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3"]),
                "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
            ]
            try expect(spec.targets) == [
                Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"]),
                Target(name: "NewTarget", type: .application, platform: .iOS),
            ]
        }
    }

    describe("Project Spec Parser") {

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

        $0.it("parses sources") {
            var targetDictionary1 = validTarget
            targetDictionary1["sources"] = [
                "sourceString",
                ["path": "sourceObject"],
                ["path": "sourceWithFlagsArray", "compilerFlags": ["-Werror"]],
                ["path": "sourceWithFlagsString", "compilerFlags": "-Werror -Wextra"],
                ["path": "sourceWithExcludes", "excludes": ["Foo.swift"]],
                ["path": "sourceWithFileType", "type": "file"],
                ["path": "sourceWithGroupType", "type": "group"],
                ["path": "sourceWithFolderType", "type": "folder"],
            ]
            var targetDictionary2 = validTarget
            targetDictionary2["sources"] = "source3"

            let target1 = try Target(name: "test", jsonDictionary: targetDictionary1)
            let target2 = try Target(name: "test", jsonDictionary: targetDictionary2)

            let target1SourcesExpect = [
                TargetSource(path: "sourceString"),
                TargetSource(path: "sourceObject"),
                TargetSource(path: "sourceWithFlagsArray", compilerFlags: ["-Werror"]),
                TargetSource(path: "sourceWithFlagsString", compilerFlags: ["-Werror", "-Wextra"]),
                TargetSource(path: "sourceWithExcludes", excludes: ["Foo.swift"]),
                TargetSource(path: "sourceWithFileType", type: .file),
                TargetSource(path: "sourceWithGroupType", type: .group),
                TargetSource(path: "sourceWithFolderType", type: .folder),
            ]

            try expect(target1.sources) == target1SourcesExpect
            try expect(target2.sources) == ["source3"]
        }

        $0.it("parses target dependencies") {
            var targetDictionary = validTarget
            targetDictionary["dependencies"] = [
                ["target": "name", "embed": false],
                ["carthage": "name"],
                ["framework": "path"],
            ]
            let target = try Target(name: "test", jsonDictionary: targetDictionary)
            try expect(target.dependencies.count) == 3
            try expect(target.dependencies[0]) == Dependency(type: .target, reference: "name", embed: false)
            try expect(target.dependencies[1]) == Dependency(type: .carthage, reference: "name")
            try expect(target.dependencies[2]) == Dependency(type: .framework, reference: "path")
        }

        $0.it("parses cross platform targets") {
            let targetDictionary: [String: Any] = [
                "platform": ["iOS", "tvOS"],
                "type": "framework",
                "sources": ["Framework", "Framework $platform"],
                "settings": ["SETTING": "value_$platform"],
            ]

            let spec = try getProjectSpec(["targets": ["Framework": targetDictionary]])
            var target_iOS = Target(name: "Framework_iOS", type: .framework, platform: .iOS)
            var target_tvOS = Target(name: "Framework_tvOS", type: .framework, platform: .tvOS)

            target_iOS.sources = ["Framework", "Framework iOS"]
            target_tvOS.sources = ["Framework", "Framework tvOS"]
            target_iOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_iOS"]
            target_tvOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_tvOS"]

            try expect(spec.targets.count) == 2
            try expect(spec.targets) == [target_iOS, target_tvOS]
        }

        $0.it("parses target schemes") {
            var targetDictionary = validTarget
            targetDictionary["scheme"] = [
                "environmentVariables": [
                    "TEST_VAR": "TEST_VAL"
                ]
            ]

            let target = try Target(name: "test", jsonDictionary: targetDictionary)

            let expectedVariables = [XCScheme.EnvironmentVariable(variable: "TEST_VAR", value: "TEST_VAL", enabled: true)]

            try expect(target.scheme?.environmentVariables) == expectedVariables
        }

        $0.it("parses schemes") {
            let schemeDictionary: [String: Any] = [
                "build": [
                    "parallelizeBuild": false,
                    "buildImplicitDependencies": false,
                    "targets": [
                        "Target1": "all",
                        "Target2": "testing",
                        "Target3": "none",
                        "Target4": ["testing": true],
                        "Target5": ["testing": false],
                        "Target6": ["test", "analyze"],
                    ],
                    "preActions": [
                        [
                            "script": "echo Before Build",
                            "name": "Before Build",
                            "settingsTarget": "Target1",
                        ],
                    ],
                ],
            ]
            let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)
            let expectedTargets: [Scheme.BuildTarget] = [
                Scheme.BuildTarget(target: "Target1", buildTypes: BuildType.all),
                Scheme.BuildTarget(target: "Target2", buildTypes: [.testing, .analyzing]),
                Scheme.BuildTarget(target: "Target3", buildTypes: []),
                Scheme.BuildTarget(target: "Target4", buildTypes: [.testing]),
                Scheme.BuildTarget(target: "Target5", buildTypes: []),
                Scheme.BuildTarget(target: "Target6", buildTypes: [.testing, .analyzing]),
            ]
            try expect(scheme.name) == "Scheme"
            try expect(scheme.build.targets) == expectedTargets
            try expect(scheme.build.preActions.first?.script) == "echo Before Build"
            try expect(scheme.build.preActions.first?.name) == "Before Build"
            try expect(scheme.build.preActions.first?.settingsTarget) == "Target1"

            try expect(scheme.build.parallelizeBuild) == false
            try expect(scheme.build.buildImplicitDependencies) == false
        }

        $0.it("parses schemes variables") {
            let schemeDictionary: [String: Any] = [
                "build": [
                    "targets": ["Target1": "all"],
                ],
                "run": [
                    "environmentVariables": [
                        ["variable": "ENVIRONMENT", "value": "VARIABLE"],
                        ["variable": "OTHER_ENV_VAR", "value": "VAL", "isEnabled": false],
                    ],
                ],
                "test": [
                    "environmentVariables": [
                        "TEST": "VARIABLE"
                    ]
                ],
                "profile": [
                    "config": "Release"
                ]
            ]

            let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)

            let expectedRunVariables = [
                XCScheme.EnvironmentVariable(variable: "ENVIRONMENT", value: "VARIABLE", enabled: true),
                XCScheme.EnvironmentVariable(variable: "OTHER_ENV_VAR", value: "VAL", enabled: false)
            ]

            let expectedTestVariables = [XCScheme.EnvironmentVariable(variable: "TEST", value: "VARIABLE", enabled: true)]

            try expect(scheme.run?.environmentVariables) == expectedRunVariables
            try expect(scheme.test?.environmentVariables) == expectedTestVariables
            try expect(scheme.profile?.config) == "Release"
            try expect(scheme.profile?.environmentVariables.isEmpty) == true
        }

        $0.it("parses settings") {
            let spec = try ProjectSpec(path: fixturePath + "settings_test.yml")
            let buildSettings: BuildSettings = ["SETTING": "value"]
            let configSettings: [String: Settings] = ["config1": Settings(buildSettings: ["SETTING1": "value"])]
            let groups = ["preset1"]

            let preset1 = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
            let preset2 = Settings(buildSettings: [:], configSettings: configSettings, groups: [])
            let preset3 = Settings(buildSettings: buildSettings, configSettings: configSettings, groups: [])
            let preset4 = Settings(buildSettings: buildSettings, configSettings: [:], groups: [])
            let preset5 = Settings(buildSettings: buildSettings, configSettings: [:], groups: groups)
            let preset6 = Settings(buildSettings: buildSettings, configSettings: configSettings, groups: groups)
            let preset7 = Settings(buildSettings: buildSettings, configSettings: ["config1": Settings(buildSettings: buildSettings, groups: groups)])
            let preset8 = Settings(buildSettings: [:], configSettings: ["config1": Settings(configSettings: configSettings)])

            try expect(spec.settingGroups.count) == 8
            try expect(spec.settingGroups["preset1"]) == preset1
            try expect(spec.settingGroups["preset2"]) == preset2
            try expect(spec.settingGroups["preset3"]) == preset3
            try expect(spec.settingGroups["preset4"]) == preset4
            try expect(spec.settingGroups["preset5"]) == preset5
            try expect(spec.settingGroups["preset6"]) == preset6
            try expect(spec.settingGroups["preset7"]) == preset7
            try expect(spec.settingGroups["preset8"]) == preset8
        }

        $0.it("parses run scripts") {
            var target = validTarget
            let scripts: [[String: Any]] = [
                ["path": "script.sh"],
                ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "runOnlyWhenInstalling": true],
            ]
            target["prebuildScripts"] = scripts
            target["postbuildScripts"] = scripts

            let expectedScripts = [
                BuildScript(script: .path("script.sh")),
                BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: true),
            ]

            let parsedTarget = try Target(name: "test", jsonDictionary: target)
            try expect(parsedTarget.prebuildScripts) == expectedScripts
            try expect(parsedTarget.postbuildScripts) == expectedScripts
        }

        $0.it("parses options") {
            let options = ProjectSpec.Options(
                carthageBuildPath: "../Carthage/Build",
                carthageExecutablePath: "../bin/carthage",
                createIntermediateGroups: true,
                bundleIdPrefix: "com.test",
                developmentLanguage: "ja",
                deploymentTarget: DeploymentTarget(
                    iOS: "11.1",
                    tvOS: "10.0",
                    watchOS: "3.0",
                    macOS: "10.12.1"
                )
            )
            let expected = ProjectSpec(basePath: "", name: "test", options: options)
            let dictionary: [String: Any] = ["options": [
                "carthageBuildPath": "../Carthage/Build",
                "carthageExecutablePath": "../bin/carthage",
                "bundleIdPrefix": "com.test",
                "createIntermediateGroups": true,
                "developmentLanguage": "ja",
                "deploymentTarget": ["iOS": 11.1, "tvOS": 10.0, "watchOS": "3", "macOS": "10.12.1"],
            ]]
            let parsedSpec = try getProjectSpec(dictionary)
            try expect(parsedSpec) == expected
        }
    }
}
