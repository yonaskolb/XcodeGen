import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import XcodeProj
import XCTest
import Yams
import TestSupport

private let app = Target(
    name: "MyApp",
    type: .application,
    platform: .iOS,
    dependencies: [Dependency(type: .target, reference: "MyFramework")]
)

private let framework = Target(
    name: "MyFramework",
    type: .framework,
    platform: .iOS
)

private let frameworkTest = Target(
    name: "MyFrameworkTests",
    type: .unitTestBundle,
    platform: .iOS
)

private let optionalFramework = Target(
    name: "MyOptionalFramework",
    type: .framework,
    platform: .iOS
)

private let uiTest = Target(
    name: "MyAppUITests",
    type: .uiTestBundle,
    platform: .iOS,
    dependencies: [Dependency(type: .target, reference: "MyApp")]
)

class SchemeGeneratorTests: XCTestCase {

    func testSchemes() {
        describe {

            let buildTarget = Scheme.BuildTarget(target: .local(app.name))
            $0.it("generates scheme") {
                let preAction = Scheme.ExecutionAction(name: "Script", script: "echo Starting", settingsTarget: app.name)
                let simulateLocation = Scheme.SimulateLocation(allow: true, defaultLocation: "New York, NY, USA")
                let scheme = Scheme(
                    name: "MyScheme",
                    build: Scheme.Build(targets: [buildTarget], preActions: [preAction]),
                    run: Scheme.Run(config: "Debug", askForAppToLaunch: true, launchAutomaticallySubstyle: "2", simulateLocation: simulateLocation, customLLDBInit: "/sample/.lldbinit"),
                    test: Scheme.Test(config: "Debug", customLLDBInit: "/test/.lldbinit")
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()
                let target = try unwrap(xcodeProject.pbxproj.nativeTargets
                    .first(where: { $0.name == app.name }))
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(scheme.name) == "MyScheme"
                try expect(xcscheme.buildAction?.buildImplicitDependencies) == true
                try expect(xcscheme.buildAction?.parallelizeBuild) == true
                try expect(xcscheme.buildAction?.preActions.first?.title) == "Script"
                try expect(xcscheme.buildAction?.preActions.first?.scriptText) == "echo Starting"
                try expect(xcscheme.buildAction?.preActions.first?.environmentBuildable?.buildableName) == "MyApp.app"
                try expect(xcscheme.buildAction?.preActions.first?.environmentBuildable?.blueprintName) == "MyApp"
                let buildActionEntry = try unwrap(xcscheme.buildAction?.buildActionEntries.first)
                try expect(buildActionEntry.buildFor) == BuildType.all

                let buildableReferences: [XCScheme.BuildableReference] = [
                    buildActionEntry.buildableReference,
                    xcscheme.launchAction?.runnable?.buildableReference,
                    xcscheme.profileAction?.buildableProductRunnable?.buildableReference,
                    xcscheme.testAction?.macroExpansion,
                ].compactMap { $0 }

                for buildableReference in buildableReferences {
                    // FIXME: try expect(buildableReference.blueprintIdentifier) == target.reference
                    try expect(buildableReference.blueprintName) == target.name
                    try expect(buildableReference.buildableName) == "\(target.name).\(target.productType!.fileExtension!)"
                }

                try expect(xcscheme.launchAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Release"

                try expect(xcscheme.launchAction?.selectedDebuggerIdentifier) == XCScheme.defaultDebugger
                try expect(xcscheme.testAction?.selectedDebuggerIdentifier) == XCScheme.defaultDebugger

                try expect(xcscheme.launchAction?.askForAppToLaunch) == true
                try expect(xcscheme.launchAction?.launchAutomaticallySubstyle) == "2"
                try expect(xcscheme.launchAction?.allowLocationSimulation) == true
                try expect(xcscheme.launchAction?.locationScenarioReference?.referenceType) == Scheme.SimulateLocation.ReferenceType.predefined.rawValue
                try expect(xcscheme.launchAction?.locationScenarioReference?.identifier) == "New York, NY, USA"
                try expect(xcscheme.launchAction?.customLLDBInitFile) == "/sample/.lldbinit"
                try expect(xcscheme.testAction?.customLLDBInitFile) == "/test/.lldbinit"
            }

            let frameworkTarget = Scheme.BuildTarget(target: .local(framework.name), buildTypes: [.archiving])
            $0.it("generates a scheme with the first runnable selected") {
                let scheme = Scheme(
                    name: "MyScheme",
                    build: Scheme.Build(targets: [frameworkTarget, buildTarget])
                )
                let project = Project(
                    name: "test",
                    targets: [framework, app],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                let buildableReference = xcscheme.launchAction?.runnable?.buildableReference
                try expect(buildableReference?.buildableName) == "MyApp.app"
            }

            $0.it("generates scheme with multiple configs") {
                let configs: [Config] = [
                    Config(name: "Beta", type: .debug),
                    Config(name: "Debug", type: .debug),
                    Config(name: "Production", type: .release),
                    Config(name: "Release", type: .release),
                ]
                let framework = Target(
                    name: "MyFramework",
                    type: .application,
                    platform: .iOS,
                    scheme: TargetScheme(testTargets: ["MyFrameworkTests"])
                )
                let project = Project(
                    name: "test",
                    configs: configs,
                    targets: [framework, frameworkTest]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.launchAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Release"
            }

            $0.it("sets environment variables for a scheme") {
                let runVariables: [XCScheme.EnvironmentVariable] = [
                    XCScheme.EnvironmentVariable(variable: "RUN_ENV", value: "ENABLED", enabled: true),
                    XCScheme.EnvironmentVariable(variable: "OTHER_RUN_ENV", value: "DISABLED", enabled: false),
                ]

                let scheme = Scheme(
                    name: "EnvironmentVariablesScheme",
                    build: Scheme.Build(targets: [buildTarget]),
                    run: Scheme.Run(config: "Debug", environmentVariables: runVariables),
                    test: Scheme.Test(config: "Debug"),
                    profile: Scheme.Profile(config: "Debug")
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(
                    xcodeProject.pbxproj.nativeTargets
                        .contains(where: { $0.name == app.name })
                ).beTrue()
                try expect(xcscheme.launchAction?.environmentVariables) == runVariables
                try expect(xcscheme.testAction?.environmentVariables).to.beNil()
                try expect(xcscheme.profileAction?.environmentVariables).to.beNil()
            }

            $0.it("generates target schemes from config variant") {
                let configVariants = ["Test", "Production"]
                var target = app
                target.scheme = TargetScheme(configVariants: configVariants)
                let configs: [Config] = [
                    Config(name: "Test Debug", type: .debug),
                    Config(name: "Production Debug", type: .debug),
                    Config(name: "Test Release", type: .release),
                    Config(name: "Production Release", type: .release),
                ]

                let project = Project(name: "test", configs: configs, targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 2

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes
                    .first(where: { $0.name == "\(target.name) Test" }))
                let buildActionEntry = try unwrap(xcscheme.buildAction?.buildActionEntries.first)

                try expect(buildActionEntry.buildableReference.blueprintIdentifier.count > 0) == true

                try expect(xcscheme.launchAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.testAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.profileAction?.buildConfiguration) == "Test Release"
                try expect(xcscheme.analyzeAction?.buildConfiguration) == "Test Debug"
                try expect(xcscheme.archiveAction?.buildConfiguration) == "Test Release"
            }

            $0.it("generates environment variables for target schemes") {
                let variables: [XCScheme.EnvironmentVariable] = [XCScheme.EnvironmentVariable(variable: "env", value: "var", enabled: false)]
                var target = app
                target.scheme = TargetScheme(environmentVariables: variables)

                let project = Project(name: "test", targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 1

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.launchAction?.environmentVariables) == variables
                try expect(xcscheme.testAction?.environmentVariables) == variables
                try expect(xcscheme.profileAction?.environmentVariables) == variables
            }

            $0.it("generate scheme without debugger - run") {
                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [buildTarget]),
                    run: Scheme.Run(config: "Debug", debugEnabled: false)
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.launchAction?.selectedDebuggerIdentifier) == ""
                try expect(xcscheme.launchAction?.selectedLauncherIdentifier) == "Xcode.IDEFoundation.Launcher.PosixSpawn"
            }

            $0.it("generate scheme without debugger - test") {
                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [buildTarget]),
                    test: Scheme.Test(config: "Debug", debugEnabled: false)
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.testAction?.selectedDebuggerIdentifier) == ""
                try expect(xcscheme.testAction?.selectedLauncherIdentifier) == "Xcode.IDEFoundation.Launcher.PosixSpawn"
            }

            $0.it("generates pre and post actions for target schemes") {
                var target = app
                target.scheme = TargetScheme(
                    preActions: [.init(name: "Run", script: "do")],
                    postActions: [.init(name: "Run2", script: "post", settingsTarget: "MyApp")]
                )

                let project = Project(name: "test", targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 1

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.buildAction?.preActions.count) == 1
                try expect(xcscheme.buildAction?.preActions.first?.title) == "Run"
                try expect(xcscheme.buildAction?.preActions.first?.scriptText) == "do"
                try expect(xcscheme.buildAction?.postActions.first?.environmentBuildable?.blueprintName) == "MyApp"

                try expect(xcscheme.launchAction?.preActions.count) == 0
                try expect(xcscheme.testAction?.postActions.count) == 0
            }

            $0.it("generates scheme using external project file") {
                prepareXcodeProj: do {
                    let project = try! Project(path: fixturePath + "scheme_test/test_project.yml")
                    let generator = ProjectGenerator(project: project)
                    let writer = FileWriter(project: project)
                    let xcodeProject = try! generator.generateXcodeProject()
                    try! writer.writeXcodeProject(xcodeProject)
                    try! writer.writePlists()
                }
                let externalProjectPath = fixturePath + "scheme_test/TestProject.xcodeproj"
                let projectReference = ProjectReference(name: "ExternalProject", path: externalProjectPath.string)
                let target = Scheme.BuildTarget(target: .init(name: "ExternalTarget", location: .project("ExternalProject")))
                let scheme = Scheme(
                    name: "ExternalProjectScheme",
                    build: Scheme.Build(targets: [target])
                )
                let project = Project(
                    name: "test",
                    targets: [],
                    schemes: [scheme],
                    projectReferences: [projectReference]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.buildAction?.buildActionEntries.count) == 1
                let buildableReference = xcscheme.buildAction?.buildActionEntries.first?.buildableReference
                try expect(buildableReference?.blueprintName) == "ExternalTarget"
                try expect(buildableReference?.referencedContainer) == "container:\(externalProjectPath.string)"

            }

            $0.it("generate scheme with code coverage options") {
                prepareXcodeProj: do {
                    let project = try! Project(path: fixturePath + "scheme_test/test_project.yml")
                    let generator = ProjectGenerator(project: project)
                    let writer = FileWriter(project: project)
                    let xcodeProject = try! generator.generateXcodeProject()
                    try! writer.writeXcodeProject(xcodeProject)
                    try! writer.writePlists()
                }
                let externalProject = fixturePath + "scheme_test/TestProject.xcodeproj"
                let externalTarget = Scheme.BuildTarget(target: .init(name: "ExternalTarget", location: .project("TestProject")))
                let scheme = try Scheme(
                    name: "CodeCoverageScheme",
                    build: Scheme.Build(targets: [externalTarget]),
                    test: Scheme.Test(
                        config: "Debug",
                        gatherCoverageData: true,
                        coverageTargets: [
                            "TestProject/ExternalTarget",
                            TargetReference(framework.name),
                        ]
                    )
                )
                let project = Project(
                    name: "test",
                    targets: [framework],
                    schemes: [scheme],
                    projectReferences: [
                        ProjectReference(name: "TestProject", path: externalProject.string),
                    ]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.codeCoverageEnabled) == true
                try expect(xcscheme.testAction?.codeCoverageTargets.count) == 2
                let buildableReference = xcscheme.testAction?.codeCoverageTargets.first
                try expect(buildableReference?.blueprintName) == "ExternalTarget"
                try expect(buildableReference?.referencedContainer) == "container:\(externalProject.string)"
            }

            $0.it("generates scheme with buildable product runnable for ios app target") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    scheme: TargetScheme()
                )
                let project = Project(name: "ios_test", targets: [app])
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.launchAction?.runnable).beOfType(XCScheme.BuildableProductRunnable.self)
            }

            $0.it("generates scheme with remote runnable for watch app target") {
                let xcscheme = try self.makeWatchScheme(appType: .watch2App, extensionType: .watch2Extension)
                try expect(xcscheme.launchAction?.runnable).beOfType(XCScheme.RemoteRunnable.self)
            }

            $0.it("generates scheme with host target build action for watch") {
                let xcscheme = try self.makeWatchScheme(appType: .watch2App, extensionType: .watch2Extension)
                let buildEntries = xcscheme.buildAction?.buildActionEntries ?? []
                try expect(buildEntries.count) == 2
                try expect(buildEntries.first?.buildableReference.blueprintName) == "WatchApp"
                try expect(buildEntries.last?.buildableReference.blueprintName) == "HostApp"
            }
        }
    }

    // MARK: - Helpers

    private func makeWatchScheme(appType: PBXProductType, extensionType: PBXProductType) throws -> XCScheme {
        let watchExtension = Target(
            name: "WatchExtension",
            type: extensionType,
            platform: .watchOS
        )
        let watchApp = Target(
            name: "WatchApp",
            type: appType,
            platform: .watchOS,
            dependencies: [Dependency(type: .target, reference: watchExtension.name)],
            scheme: TargetScheme()
        )
        let hostApp = Target(
            name: "HostApp",
            type: .application,
            platform: .iOS,
            dependencies: [Dependency(type: .target, reference: watchApp.name)]
        )
        let project = Project(
            name: "watch_test",
            targets: [hostApp, watchApp, watchExtension]
        )
        let xcodeProject = try project.generateXcodeProject()
        return try unwrap(xcodeProject.sharedData?.schemes.first)
    }
}
