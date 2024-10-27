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

    func testSchemes() throws {
        try skipIfNecessary()
        describe {

            let buildTarget = Scheme.BuildTarget(target: .local(app.name))
            $0.it("generates scheme") {
                let preAction = Scheme.ExecutionAction(name: "Script", script: "echo Starting", settingsTarget: app.name)
                let simulateLocation = Scheme.SimulateLocation(allow: true, defaultLocation: "New York, NY, USA")
                let storeKitConfiguration = "Configuration.storekit"
                let scheme = try Scheme(
                    name: "MyScheme",
                    build: Scheme.Build(targets: [buildTarget], preActions: [preAction]),
                    run: Scheme.Run(config: "Debug", enableGPUFrameCaptureMode: .metal, askForAppToLaunch: true, launchAutomaticallySubstyle: "2", simulateLocation: simulateLocation, storeKitConfiguration: storeKitConfiguration, customLLDBInit: "/sample/.lldbinit"),
                    test: Scheme.Test(config: "Debug", targets: [
                        Scheme.Test.TestTarget(targetReference: TestableTargetReference(framework.name), location: "test.gpx"),
                        Scheme.Test.TestTarget(targetReference: TestableTargetReference(framework.name), location: "New York, NY, USA")
                    ], customLLDBInit: "/test/.lldbinit"),
                    profile: Scheme.Profile(config: "Release", askForAppToLaunch: true)
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme],
                    options: .init(schemePathPrefix: "../")
                )
                let xcodeProject = try project.generateXcodeProject()
                let target = try unwrap(xcodeProject.pbxproj.nativeTargets
                    .first(where: { $0.name == app.name }))
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(scheme.name) == "MyScheme"
                try expect(xcscheme.buildAction?.buildImplicitDependencies) == true
                try expect(xcscheme.buildAction?.parallelizeBuild) == true
                try expect(xcscheme.buildAction?.runPostActionsOnFailure) == false
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
                try expect(xcscheme.profileAction?.askForAppToLaunch) == true
                try expect(xcscheme.launchAction?.launchAutomaticallySubstyle) == "2"
                try expect(xcscheme.launchAction?.allowLocationSimulation) == true
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../Configuration.storekit"
                try expect(xcscheme.launchAction?.locationScenarioReference?.referenceType) == Scheme.SimulateLocation.ReferenceType.predefined.rawValue
                try expect(xcscheme.launchAction?.locationScenarioReference?.identifier) == "New York, NY, USA"
                try expect(xcscheme.launchAction?.customLLDBInitFile) == "/sample/.lldbinit"
                try expect(xcscheme.launchAction?.enableGPUFrameCaptureMode) == .metal
                try expect(xcscheme.testAction?.customLLDBInitFile) == "/test/.lldbinit"
                try expect(xcscheme.testAction?.systemAttachmentLifetime).to.beNil()
                
                try expect(xcscheme.testAction?.testables[0].locationScenarioReference?.referenceType) == "0"
                try expect(xcscheme.testAction?.testables[0].locationScenarioReference?.identifier) == "../test.gpx"
                
                try expect(xcscheme.testAction?.testables[1].locationScenarioReference?.referenceType) == "1"
                try expect(xcscheme.testAction?.testables[1].locationScenarioReference?.identifier) == "New York, NY, USA"
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
                    scheme: TargetScheme(testTargets: ["MyFrameworkTests"], storeKitConfiguration: "Configuration.storekit")
                )
                let project = Project(
                    name: "test",
                    configs: configs,
                    targets: [framework, frameworkTest],
                    options: .init(schemePathPrefix: "../../")
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(xcscheme.launchAction?.buildConfiguration) == "Debug"
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../../Configuration.storekit"
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
                    run: Scheme.Run(config: "Debug", environmentVariables: runVariables, simulateLocation: .init(allow: true, defaultLocation: "File.gpx"), storeKitConfiguration: "Configuration.storekit"),
                    test: Scheme.Test(config: "Debug"),
                    profile: Scheme.Profile(config: "Debug")
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme],
                    options: .init(schemePathPrefix: "../")
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)

                try expect(
                    xcodeProject.pbxproj.nativeTargets
                        .contains(where: { $0.name == app.name })
                ).beTrue()
                try expect(xcscheme.launchAction?.environmentVariables) == runVariables
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../Configuration.storekit"
                try expect(xcscheme.launchAction?.locationScenarioReference?.referenceType) == Scheme.SimulateLocation.ReferenceType.gpx.rawValue
                try expect(xcscheme.launchAction?.locationScenarioReference?.identifier) == "../File.gpx"
                try expect(xcscheme.testAction?.environmentVariables).to.beNil()
                try expect(xcscheme.profileAction?.environmentVariables).to.beNil()
            }

            $0.it("generates target schemes from config variant") {
                let configVariants = ["Test", "PreProd", "Prod"]
                var target = app
                target.scheme = TargetScheme(configVariants: configVariants)
                
                // Including here a double test for custom upper/lowercase, and dash delimited in config types
                let configs: [Config] = [
                    Config(name: "Test-Debug", type: .debug),
                    Config(name: "PreProd debug", type: .debug),
                    Config(name: "Prod-Debug", type: .debug),
                    Config(name: "Test Release", type: .release),
                    Config(name: "PreProd release", type: .release),
                    Config(name: "Prod Release", type: .release),
                ]

                let project = Project(name: "test", configs: configs, targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()

                try expect(xcodeProject.sharedData?.schemes.count) == 3
                try configVariants.forEach { variantName in
                    let xcscheme = try unwrap(xcodeProject.sharedData?.schemes
                                                .first(where: { $0.name == "\(target.name) \(variantName)" }))
                    let buildActionEntry = try unwrap(xcscheme.buildAction?.buildActionEntries.first)
                    
                    try expect((buildActionEntry.buildableReference.blueprintIdentifier?.count ?? 0) > 0) == true
                    if variantName == "PreProd" {
                        try expect(xcscheme.launchAction?.buildConfiguration) == "\(variantName) debug"
                        try expect(xcscheme.testAction?.buildConfiguration) == "\(variantName) debug"
                        try expect(xcscheme.profileAction?.buildConfiguration) == "\(variantName) release"
                        try expect(xcscheme.analyzeAction?.buildConfiguration) == "\(variantName) debug"
                        try expect(xcscheme.archiveAction?.buildConfiguration) == "\(variantName) release"
                    } else {
                        try expect(xcscheme.launchAction?.buildConfiguration) == "\(variantName)-Debug"
                        try expect(xcscheme.testAction?.buildConfiguration) == "\(variantName)-Debug"
                        try expect(xcscheme.profileAction?.buildConfiguration) == "\(variantName) Release"
                        try expect(xcscheme.analyzeAction?.buildConfiguration) == "\(variantName)-Debug"
                        try expect(xcscheme.archiveAction?.buildConfiguration) == "\(variantName) Release"
                    }
                }
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
                    run: Scheme.Run(config: "Debug", enableGPUFrameCaptureMode: .metal, debugEnabled: false, simulateLocation: .init(allow: true, defaultLocation: "File.gpx"), storeKitConfiguration: "Configuration.storekit")
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
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../../Configuration.storekit"
                try expect(xcscheme.launchAction?.locationScenarioReference?.referenceType) == Scheme.SimulateLocation.ReferenceType.gpx.rawValue
                try expect(xcscheme.launchAction?.locationScenarioReference?.identifier) == "../../File.gpx"
                try expect(xcscheme.launchAction?.enableGPUFrameCaptureMode) == .metal
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

            $0.it("generates target schemes with code coverage options") {
                var target = app
                target.scheme = try TargetScheme(
                    gatherCoverageData: true,
                    coverageTargets: [
                        TestableTargetReference(framework.name),
                    ]
                )

                let project = Project(name: "test", targets: [target, framework])
                let xcodeProject = try project.generateXcodeProject()
                try expect(xcodeProject.sharedData?.schemes.count) == 1

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.codeCoverageEnabled) == true
                try expect(xcscheme.testAction?.codeCoverageTargets.count) == 1
                try expect(xcscheme.testAction?.codeCoverageTargets.first?.blueprintName) == framework.name
            }

            $0.it("generates scheme using external project file") {
                prepareXcodeProj: do {
                    let project = try! Project(path: fixturePath + "scheme_test/test_project.yml")
                    let generator = ProjectGenerator(project: project)
                    let writer = FileWriter(project: project)
                    let xcodeProject = try! generator.generateXcodeProject(userName: "someUser")
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
                    let xcodeProject = try! generator.generateXcodeProject(userName: "someUser")
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
                            TestableTargetReference(framework.name),
                            TestableTargetReference(name: "XcodeGenKitTests", location: .package("XcodeGen"))
                        ]
                    )
                )
                let project = Project(
                    name: "test",
                    targets: [framework],
                    schemes: [scheme],
                    packages: ["XcodeGen": .local(path: "../", group: nil)],
                    projectReferences: [
                        ProjectReference(name: "TestProject", path: externalProject.string),
                    ]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.codeCoverageEnabled) == true
                try expect(xcscheme.testAction?.codeCoverageTargets.count) == 3
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
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../Configuration.storekit"
            }

            $0.it("generates scheme with host target build action for watch") {
                let xcscheme = try self.makeWatchScheme(appType: .watch2App, extensionType: .watch2Extension)
                let buildEntries = xcscheme.buildAction?.buildActionEntries ?? []
                try expect(buildEntries.count) == 2
                try expect(buildEntries.first?.buildableReference.blueprintName) == "WatchApp"
                try expect(buildEntries.last?.buildableReference.blueprintName) == "HostApp"
                try expect(xcscheme.launchAction?.storeKitConfigurationFileReference?.identifier) == "../Configuration.storekit"
            }
            
            $0.it("generates scheme with extension target and specify macroExpansion") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: "MyAppExtension", embed: false)]
                )

                let `extension` = Target(
                    name: "MyAppExtension",
                    type: .appExtension,
                    platform: .iOS
                )
                let appTarget = Scheme.BuildTarget(target: .local(app.name), buildTypes: [.running])
                let extensionTarget = Scheme.BuildTarget(target: .local(`extension`.name), buildTypes: [.running])
            
                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [appTarget, extensionTarget]),
                    run: Scheme.Run(config: "Debug", macroExpansion: "MyApp")
                )
                let project = Project(
                    name: "test",
                    targets: [app, `extension`],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.macroExpansion?.buildableName) == "MyApp.app"
                try expect(xcscheme.launchAction?.macroExpansion?.buildableName) == "MyApp.app"
            }

            $0.it("allows to override test macroExpansion") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [Dependency(type: .target, reference: "MyAppExtension", embed: false)]
                )

                let `extension` = Target(
                    name: "MyAppExtension",
                    type: .appExtension,
                    platform: .iOS
                )
                let appTarget = Scheme.BuildTarget(target: .local(app.name), buildTypes: [.running])
                let extensionTarget = Scheme.BuildTarget(target: .local(`extension`.name), buildTypes: [.running])
            
                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [appTarget, extensionTarget]),
                    run: Scheme.Run(config: "Debug", macroExpansion: "MyApp"),
                    test: .init(macroExpansion: "MyAppExtension")
                )
                let project = Project(
                    name: "test",
                    targets: [app, `extension`],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.macroExpansion?.buildableName) == "MyAppExtension.appex"
                try expect(xcscheme.launchAction?.macroExpansion?.buildableName) == "MyApp.app"
            }
            
            $0.it("generates scheme with macroExpansion from tests when the main target is not part of the scheme") {
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: []
                )

                let mockApp = Target(
                    name: "MockApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: []
                )

                let testBundle = Target(
                    name: "TestBundle",
                    type: .unitTestBundle,
                    platform: .iOS
                )
                let appTarget = Scheme.BuildTarget(target: .local(app.name), buildTypes: [.running])
                let mockAppTarget = Scheme.BuildTarget(target: .local(mockApp.name), buildTypes: [.testing])
                let testBundleTarget = Scheme.BuildTarget(target: .local(testBundle.name), buildTypes: [.testing])

                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [appTarget, mockAppTarget, testBundleTarget]),
                    run: Scheme.Run(config: "Debug", macroExpansion: "MyApp")
                )
                let project = Project(
                    name: "test",
                    targets: [app, mockApp, testBundle],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.macroExpansion?.buildableName) == "MockApp.app"
            }

            $0.it("generates scheme with test target of local swift package") {
                let targetScheme = TargetScheme(
                    testTargets: [Scheme.Test.TestTarget(targetReference: TestableTargetReference(name: "XcodeGenKitTests", location: .package("XcodeGen")))])
                let app = Target(
                    name: "MyApp",
                    type: .application,
                    platform: .iOS,
                    dependencies: [
                        Dependency(type: .package(products: []), reference: "XcodeGen")
                    ],
                    scheme: targetScheme
                )
                let project = Project(
                    name: "ios_test",
                    targets: [app],
                    packages: ["XcodeGen": .local(path: "../", group: nil)]
                )
                let xcodeProject = try project.generateXcodeProject()
                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                let buildableReference = try unwrap(xcscheme.testAction?.testables.first?.buildableReference)

                try expect(buildableReference.blueprintIdentifier) == "XcodeGenKitTests"
                try expect(buildableReference.blueprintName) == "XcodeGenKitTests"
                try expect(buildableReference.buildableName) == "XcodeGenKitTests"
                try expect(buildableReference.referencedContainer) == "container:../"
            }

            $0.it("generates scheme capturing screenshots automatically and deleting on success") {
                let xcscheme = try self.makeSnapshotScheme(
                    buildTarget: buildTarget,
                    captureScreenshotsAutomatically: true,
                    deleteScreenshotsWhenEachTestSucceeds: true)

                try expect(xcscheme.testAction?.systemAttachmentLifetime).to.beNil()
            }

            $0.it("generates scheme capturing screenshots and not deleting") {
                let xcscheme = try self.makeSnapshotScheme(
                    buildTarget: buildTarget,
                    captureScreenshotsAutomatically: true,
                    deleteScreenshotsWhenEachTestSucceeds: false)

                try expect(xcscheme.testAction?.systemAttachmentLifetime) == .keepAlways
            }

            $0.it("generates scheme not capturing screenshots") {
                let xcscheme = try self.makeSnapshotScheme(
                    buildTarget: buildTarget,
                    captureScreenshotsAutomatically: false,
                    deleteScreenshotsWhenEachTestSucceeds: false)

                try expect(xcscheme.testAction?.systemAttachmentLifetime) == .keepNever
            }

            $0.it("ignores screenshot delete preference when not capturing screenshots") {
                let xcscheme = try self.makeSnapshotScheme(
                    buildTarget: buildTarget,
                    captureScreenshotsAutomatically: false,
                    deleteScreenshotsWhenEachTestSucceeds: true)

                try expect(xcscheme.testAction?.systemAttachmentLifetime) == .keepNever
            }

            $0.it("generate test plans ") {

                let testPlanPath1 = "\(fixturePath.string)/TestProject/App_iOS/App_iOS.xctestplan"
                let testPlanPath2 = "\(fixturePath.string)/TestProject/App_iOS/App_iOS.xctestplan"

                let scheme = Scheme(
                    name: "TestScheme",
                    build: Scheme.Build(targets: [buildTarget]),
                    test: Scheme.Test(config: "Debug", testPlans: [
                        .init(path: testPlanPath1, defaultPlan: false),
                        .init(path: testPlanPath2, defaultPlan: true),
                    ])
                )
                let project = Project(
                    name: "test",
                    targets: [app, framework],
                    schemes: [scheme]
                )
                let xcodeProject = try project.generateXcodeProject()

                let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
                try expect(xcscheme.testAction?.testPlans) == [
                    .init(reference: "container:\(testPlanPath1)", default: false),
                    .init(reference: "container:\(testPlanPath2)", default: true),
                ]
            }
        }
    }
    
    func testOverrideLastUpgradeVersionWhenUserDidSpecify() throws {
        var target = app
        target.scheme = TargetScheme()
        
        let lastUpgradeKey = "LastUpgradeCheck"
        let lastUpgradeValue = "1234"
        let attributes: [String: Any] = [lastUpgradeKey: lastUpgradeValue]
        let project = Project(name: "test", targets: [target, framework], attributes: attributes)
        let xcodeProject = try project.generateXcodeProject()

        let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
        XCTAssertEqual(xcscheme.lastUpgradeVersion, lastUpgradeValue)
    }


    func testDefaultLastUpgradeVersionWhenUserDidNotSpecify() throws {
        var target = app
        target.scheme = TargetScheme()

        let project = Project(name: "test", targets: [target, framework])
        let xcodeProject = try project.generateXcodeProject()

        let xcscheme = try unwrap(xcodeProject.sharedData?.schemes.first)
        XCTAssertEqual(xcscheme.lastUpgradeVersion, project.xcodeVersion)
    }

    func testGenerateSchemeManagementOnHiddenTargetScheme() throws {
        var target = app
        target.scheme = TargetScheme(management: Scheme.Management(isShown: false))

        let project = Project(name: "test", targets: [target, framework])
        let xcodeProject = try project.generateXcodeProject()

        let xcSchemeManagement = try XCTUnwrap(xcodeProject.userData.first?.schemeManagement)
        XCTAssertEqual(xcSchemeManagement.schemeUserState![0].name, "MyApp.xcscheme")
        XCTAssertEqual(xcSchemeManagement.schemeUserState![0].shared, true)
        XCTAssertEqual(xcSchemeManagement.schemeUserState![0].isShown, false)
        XCTAssertEqual(xcSchemeManagement.schemeUserState![0].orderHint, nil)
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
            scheme: TargetScheme(storeKitConfiguration: "Configuration.storekit")
        )
        let hostApp = Target(
            name: "HostApp",
            type: .application,
            platform: .iOS,
            dependencies: [Dependency(type: .target, reference: watchApp.name)]
        )
        let project = Project(
            name: "watch_test",
            targets: [hostApp, watchApp, watchExtension],
            options: .init(schemePathPrefix: "../")
        )
        let xcodeProject = try project.generateXcodeProject()
        return try unwrap(xcodeProject.sharedData?.schemes.first)
    }

    private func makeSnapshotScheme(buildTarget: Scheme.BuildTarget, captureScreenshotsAutomatically: Bool, deleteScreenshotsWhenEachTestSucceeds: Bool) throws -> XCScheme {
        let scheme = Scheme(
            name: "MyScheme",
            build: Scheme.Build(targets: [buildTarget]),
            run: Scheme.Run(config: "Debug"),
            test: Scheme.Test(config: "Debug", captureScreenshotsAutomatically: captureScreenshotsAutomatically, deleteScreenshotsWhenEachTestSucceeds: deleteScreenshotsWhenEachTestSucceeds)
        )
        let project = Project(
            name: "test",
            targets: [app, framework],
            schemes: [scheme]
        )
        let xcodeProject = try project.generateXcodeProject()
        return try unwrap(xcodeProject.sharedData?.schemes.first)
    }
}
