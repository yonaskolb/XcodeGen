import Foundation
import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcodeproj
import XCTest

class SpecLoadingTests: XCTestCase {

    func testSpecLoader() {
        describe {
            $0.it("merges includes") {
                let path = fixturePath + "include_test.yml"
                let project = try Project(path: path)

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"]),
                    Target(name: "NewTarget", type: .application, platform: .iOS, sources: ["template", "target"]),
                ]
            }

            $0.it("parses yaml types") {
                let path = fixturePath + "yaml.yml"
                let dictionary = try loadYamlDictionary(path: path)
                let expectedDictionary: [String: Any] = [
                    "true": true,
                    "false": false,
                    "yes": true,
                    "no": false,
                    "yesQuote": "YES",
                    "noQuote": "NO",
                    "int": 1,
                    "intQuote": "1",
                    "float": 3.2,
                    "floatQuote": "10.10",
                    "string": "hello",
                    "stringQuote": "hello",
                    "space": " ",
                    "empty": "",
                    "emptyQuote": "",
                    "emptyDictionary": [String: Any](),
                    "arrayLiteral": [1, 2],
                    "arrayList": [1, 2],
                ]
                for (key, expectedValue) in expectedDictionary {
                    guard let parsedValue = dictionary[key] else {
                        throw failure("\(key) does not exist")
                    }
                    if String(describing: expectedValue) != String(describing: parsedValue) {
                        throw failure("\(key): \(parsedValue) does not equal \(expectedValue)")
                    }
                }
                if !(dictionary as NSDictionary).isEqual(expectedDictionary) {
                    throw failure("parsed yaml types don't match:\n\nParsed:\n\t\(dictionary.map { "\($0.key): \($0.value)" }.joined(separator: "\n\t"))\nExpected:\n\t\(expectedDictionary.map { "\($0.key): \($0.value)" }.joined(separator: "\n\t"))")
                }
            }
        }
    }

    func testSpecLoaderLoadingJSON() {
        describe {
            $0.it("merges includes") {
                let path = fixturePath + "include_test.json"
                let project = try Project(path: path)

                try expect(project.name) == "NewName"
                try expect(project.settingGroups) == [
                    "test": Settings(dictionary: ["MY_SETTING1": "NEW VALUE", "MY_SETTING2": "VALUE2", "MY_SETTING3": "VALUE3"]),
                    "new": Settings(dictionary: ["MY_SETTING": "VALUE"]),
                    "toReplace": Settings(dictionary: ["MY_SETTING2": "VALUE2"]),
                ]
                try expect(project.targets) == [
                    Target(name: "IncludedTargetNew", type: .application, platform: .tvOS, sources: ["NewSource"]),
                    Target(name: "NewTarget", type: .application, platform: .iOS),
                ]
            }
        }
    }

    func testProjectSpecParser() {
        let validTarget: [String: Any] = ["type": "application", "platform": "iOS"]
        let invalid = "invalid"

        describe {

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
                    ["framework": "path", "weak": true],
                    ["sdk": "Contacts.framework"],
                ]
                let target = try Target(name: "test", jsonDictionary: targetDictionary)
                try expect(target.dependencies.count) == 4
                try expect(target.dependencies[0]) == Dependency(type: .target, reference: "name", embed: false)
                try expect(target.dependencies[1]) == Dependency(type: .carthage, reference: "name")
                try expect(target.dependencies[2]) == Dependency(type: .framework, reference: "path", weakLink: true)
                try expect(target.dependencies[3]) == Dependency(type: .sdk, reference: "Contacts.framework")
            }

            $0.it("parses info plist") {
                var targetDictionary = validTarget
                targetDictionary["info"] = [
                    "path": "Info.plist",
                    "properties": [
                        "CFBundleName": "MyAppName",
                        "UIBackgroundModes": ["fetch"],
                    ],
                ]

                let target = try Target(name: "", jsonDictionary: targetDictionary)
                try expect(target.info) == Plist(path: "Info.plist", attributes: [
                    "CFBundleName": "MyAppName",
                    "UIBackgroundModes": ["fetch"],
                ])
            }

            $0.it("parses entitlement plist") {
                var targetDictionary = validTarget
                targetDictionary["entitlements"] = [
                    "path": "app.entitlements",
                    "properties": [
                        "com.apple.security.application-groups": "com.group",
                    ],
                ]

                let target = try Target(name: "", jsonDictionary: targetDictionary)
                try expect(target.entitlements) == Plist(path: "app.entitlements", attributes: [
                    "com.apple.security.application-groups": "com.group",
                ])
            }

            $0.it("parses cross platform targets") {
                let targetDictionary: [String: Any] = [
                    "platform": ["iOS", "tvOS"],
                    "type": "framework",
                    "sources": ["Framework", "Framework $platform"],
                    "settings": ["SETTING": "value_$platform"],
                ]

                let project = try getProjectSpec(["targets": ["Framework": targetDictionary]])
                var target_iOS = Target(name: "Framework_iOS", type: .framework, platform: .iOS)
                var target_tvOS = Target(name: "Framework_tvOS", type: .framework, platform: .tvOS)

                target_iOS.sources = ["Framework", "Framework iOS"]
                target_tvOS.sources = ["Framework", "Framework tvOS"]
                target_iOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_iOS"]
                target_tvOS.settings = ["PRODUCT_NAME": "Framework", "SETTING": "value_tvOS"]

                try expect(project.targets.count) == 2
                try expect(project.targets) == [target_iOS, target_tvOS]
            }

            $0.it("parses target templates") {

                let targetDictionary: [String: Any] = [
                    "deploymentTarget": "1.2.0",
                    "sources": ["targetSource"],
                    "templates": ["temp2", "temp"],
                ]

                let project = try getProjectSpec([
                    "targets": ["Framework": targetDictionary],
                    "targetTemplates": [
                        "temp": [
                            "platform": "iOS",
                            "sources": ["templateSource"],
                        ],
                        "temp2": [
                            "type": "framework",
                            "platform": "tvOS",
                            "deploymentTarget": "1.1.0",
                        ],
                    ],
                ])

                let target = project.targets.first!
                try expect(target.type) == .framework // uses value
                try expect(target.platform) == .iOS // uses latest value
                try expect(target.deploymentTarget) == Version("1.2.0") // keeps value
                try expect(target.sources) == ["templateSource", "targetSource"] // merges array in order
            }

            $0.it("parses aggregate targets") {
                let dictionary: [String: Any] = [
                    "targets": ["target_1", "target_2"],
                    "settings": ["SETTING": "VALUE"],
                    "configFiles": ["debug": "file.xcconfig"],
                ]

                let project = try getProjectSpec(["aggregateTargets": ["AggregateTarget": dictionary]])
                let expectedTarget = AggregateTarget(name: "AggregateTarget", targets: ["target_1", "target_2"], settings: ["SETTING": "VALUE"], configFiles: ["debug": "file.xcconfig"])
                try expect(project.aggregateTargets) == [expectedTarget]
            }

            $0.it("parses target schemes") {
                var targetDictionary = validTarget
                targetDictionary["scheme"] = [
                    "testTargets": ["t1", ["name": "t2"]],
                    "configVariants": ["dev", "app-store"],
                    "commandLineArguments": [
                        "ENV1": true,
                    ],
                    "gatherCoverageData": true,
                    "environmentVariables": [
                        "TEST_VAR": "TEST_VAL",
                    ],
                    "preActions": [
                        [
                            "script": "dothing",
                            "name": "Do Thing",
                            "settingsTarget": "test",
                        ],
                    ],
                    "postActions": [
                        [
                            "script": "hello",
                        ],
                    ],
                ]

                let target = try Target(name: "test", jsonDictionary: targetDictionary)

                let scheme = TargetScheme(
                    testTargets: ["t1", "t2"],
                    configVariants: ["dev", "app-store"],
                    gatherCoverageData: true,
                    commandLineArguments: ["ENV1": true],
                    environmentVariables: [XCScheme.EnvironmentVariable(variable: "TEST_VAR", value: "TEST_VAL", enabled: true)],
                    preActions: [.init(name: "Do Thing", script: "dothing", settingsTarget: "test")],
                    postActions: [.init(name: "Run Script", script: "hello")]
                )

                try expect(target.scheme) == scheme
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
                    "test": [
                        "config": "debug",
                        "targets": [
                            "Target1",
                            [
                                "name": "Target2",
                                "parallelizable": true,
                                "randomExecutionOrder": true,
                            ],
                        ],
                        "gatherCoverageData": true,
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

                let expectedTest = Scheme.Test(
                    config: "debug",
                    gatherCoverageData: true,
                    targets: [
                        "Target1",
                        Scheme.Test.TestTarget(
                            name: "Target2",
                            randomExecutionOrder: true,
                            parallelizable: true
                        ),
                    ]
                )
                try expect(scheme.test) == expectedTest
            }

            $0.it("parses schemes variables") {
                let schemeDictionary: [String: Any] = [
                    "build": [
                        "targets": ["Target1": "all"],
                    ],
                    "run": [
                        "environmentVariables": [
                            ["variable": "BOOL_TRUE", "value": true],
                            ["variable": "BOOL_YES", "value": "YES"],
                            ["variable": "ENVIRONMENT", "value": "VARIABLE"],
                            ["variable": "OTHER_ENV_VAR", "value": "VAL", "isEnabled": false],
                        ],
                    ],
                    "test": [
                        "environmentVariables": [
                            "BOOL_TRUE": true,
                            "BOOL_YES": "YES",
                            "TEST": "VARIABLE",
                        ],
                    ],
                    "profile": [
                        "config": "Release",
                    ],
                ]

                let scheme = try Scheme(name: "Scheme", jsonDictionary: schemeDictionary)

                let expectedRunVariables = [
                    XCScheme.EnvironmentVariable(variable: "BOOL_TRUE", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "BOOL_YES", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "ENVIRONMENT", value: "VARIABLE", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "OTHER_ENV_VAR", value: "VAL", enabled: false),
                ]

                let expectedTestVariables = [
                    XCScheme.EnvironmentVariable(variable: "BOOL_TRUE", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "BOOL_YES", value: "YES", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "TEST", value: "VARIABLE", enabled: true),
                ]

                try expect(scheme.run?.environmentVariables) == expectedRunVariables
                try expect(scheme.test?.environmentVariables) == expectedTestVariables
                try expect(scheme.profile?.config) == "Release"
                try expect(scheme.profile?.environmentVariables.isEmpty) == true
            }

            $0.it("parses settings") {
                let project = try Project(path: fixturePath + "settings_test.yml")
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

                try expect(project.settingGroups.count) == 8
                try expect(project.settingGroups["preset1"]) == preset1
                try expect(project.settingGroups["preset2"]) == preset2
                try expect(project.settingGroups["preset3"]) == preset3
                try expect(project.settingGroups["preset4"]) == preset4
                try expect(project.settingGroups["preset5"]) == preset5
                try expect(project.settingGroups["preset6"]) == preset6
                try expect(project.settingGroups["preset7"]) == preset7
                try expect(project.settingGroups["preset8"]) == preset8
            }

            $0.it("parses run scripts") {
                var target = validTarget
                let scripts: [[String: Any]] = [
                    ["path": "script.sh"],
                    ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "runOnlyWhenInstalling": true],
                    ["script": "shell script\ndo thing", "name": "myscript", "inputFiles": ["file", "file2"], "outputFiles": ["file", "file2"], "shell": "bin/customshell", "showEnvVars": false],
                ]
                target["prebuildScripts"] = scripts
                target["postbuildScripts"] = scripts

                let expectedScripts = [
                    BuildScript(script: .path("script.sh")),
                    BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: true, showEnvVars: true),
                    BuildScript(script: .script("shell script\ndo thing"), name: "myscript", inputFiles: ["file", "file2"], outputFiles: ["file", "file2"], shell: "bin/customshell", runOnlyWhenInstalling: false, showEnvVars: false),
                ]

                let parsedTarget = try Target(name: "test", jsonDictionary: target)
                try expect(parsedTarget.prebuildScripts) == expectedScripts
                try expect(parsedTarget.postbuildScripts) == expectedScripts
            }

            $0.it("parses build rules") {
                var target = validTarget
                let buildRules: [[String: Any]] = [
                    [
                        "name": "My Rule",
                        "script": "my script",
                        "filePattern": "*.swift",
                        "outputFiles": ["file1", "file2"],
                        "outputFilesCompilerFlags": ["-a", "-b"],
                    ],
                    [
                        "compilerSpec": "apple.tool",
                        "fileType": "sourcecode.swift",
                    ],
                ]
                target["buildRules"] = buildRules

                let expectedBuildRules = [
                    BuildRule(fileType: .pattern("*.swift"), action: .script("my script"), name: "My Rule", outputFiles: ["file1", "file2"], outputFilesCompilerFlags: ["-a", "-b"]),
                    BuildRule(fileType: .type("sourcecode.swift"), action: .compilerSpec("apple.tool")),
                ]

                let parsedTarget = try Target(name: "test", jsonDictionary: target)
                try expect(parsedTarget.buildRules) == expectedBuildRules
            }

            $0.it("parses options") {
                let options = SpecOptions(
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
                let expected = Project(basePath: "", name: "test", options: options)
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

    func testDecoding() throws {
        describe {
            $0.it("decodes dots in dictionary keys") {
                let dictionary: [String: Any] = [
                    "test": [
                        "one.two": true,
                    ],
                ]

                let booleans: [String: Bool] = try dictionary.json(atKeyPath: "test")
                try expect(booleans) == ["one.two": true]
            }
        }
    }
}

@discardableResult
fileprivate func getProjectSpec(_ project: [String: Any], file: String = #file, line: Int = #line) throws -> Project {
    var projectDictionary: [String: Any] = ["name": "test"]
    for (key, value) in project {
        projectDictionary[key] = value
    }
    do {
        return try Project(basePath: "", jsonDictionary: projectDictionary)
    } catch {
        throw failure("\(error)", file: file, line: line)
    }
}

fileprivate func expectSpecError(_ project: [String: Any], _ expectedError: SpecParsingError, file: String = #file, line: Int = #line) throws {
    try expectError(expectedError, file: file, line: line) {
        try getProjectSpec(project)
    }
}

fileprivate func expectTargetError(_ target: [String: Any], _ expectedError: SpecParsingError, file: String = #file, line: Int = #line) throws {
    try expectError(expectedError, file: file, line: line) {
        _ = try Target(name: "test", jsonDictionary: target)
    }
}
