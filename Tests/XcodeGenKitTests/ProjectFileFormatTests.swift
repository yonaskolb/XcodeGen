import PathKit
import ProjectSpec
import XcodeGenKit
import XcodeProj
import XCTest
import TestSupport

class ProjectFileFormatTests: XCTestCase {

    // MARK: - Round trip

    func testFixturesRoundTripThroughXCProj() throws {
        try skipIfNecessary()
        let specs = [
            "TestProject/AnotherProject/project.yml",
            "TestProject/project.yml",
            "CarthageProject/project.yml",
            "SPM/project.yml",
            "XCProjProject/project.yml",
            "scheme_test/test_project.yml",
        ]
        // scripts/compare-xcproj-fixtures.sh checks with Xcode that the fixtures are the same projects in both formats
        for spec in specs {
            let project = try Project(path: fixturePath + spec)
            let pbxproj = try generatePBXProj(project)
            let readProject = try roundTrip(pbxproj, name: project.name)
            XCTAssertEqual(readProject.projects.flatMap(\.targets).map(\.name), pbxproj.projects.flatMap(\.targets).map(\.name), spec)
            XCTAssertEqual(readProject.buildConfigurations.map(\.name).sorted(), pbxproj.buildConfigurations.map(\.name).sorted(), spec)
        }
    }

    func testAttributesInXCProj() throws {
        let project = try makeProject(spec: """
        name: Attributes
        attributes:
          ORGANIZATIONNAME: Organization
          CUSTOM: value
        targets:
          App:
            type: application
            platform: iOS
            sources: [Sources]
            attributes:
              DevelopmentTeam: ABCDEF
              ProvisioningStyle: Manual
              CUSTOM: value
          UITests:
            type: bundle.ui-testing
            platform: iOS
            sources: [UITests]
            dependencies:
              - target: App
        """, files: ["Sources/a.swift", "UITests/test.swift"])

        let pbxproj = try roundTrip(generatePBXProj(project), name: project.name)
        let rootObject = try XCTUnwrap(pbxproj.rootObject)
        let app = try XCTUnwrap(pbxproj.nativeTargets.first { $0.name == "App" })
        let uiTests = try XCTUnwrap(pbxproj.nativeTargets.first { $0.name == "UITests" })
        let appAttributes = rootObject.targetAttributes[app] ?? [:]
        let uiTestsAttributes = rootObject.targetAttributes[uiTests] ?? [:]

        XCTAssertEqual(rootObject.attributes["ORGANIZATIONNAME"]?.stringValue, "Organization")
        XCTAssertEqual(appAttributes["DevelopmentTeam"]?.stringValue, "ABCDEF")
        XCTAssertEqual(appAttributes["ProvisioningStyle"]?.stringValue, "Manual")
        guard case let .targetReference(testTarget) = uiTestsAttributes["TestTargetID"] else {
            return XCTFail("TestTargetID wasn't kept")
        }
        XCTAssertTrue(testTarget === app)
        // the xcproj format has no place for other attributes, which is documented in ProjectSpec.md
        XCTAssertNil(rootObject.attributes["CUSTOM"])
        XCTAssertNil(appAttributes["CUSTOM"])
    }

    // MARK: - Writing

    func testDefaultProjectFileFormat() throws {
        let project = Project(name: "test")
        XCTAssertEqual(project.projectFileFormat, .pbxproj)
        let xcodeProject = try ProjectGenerator(project: project).generateXcodeProject(userName: "someUser")
        XCTAssertEqual(xcodeProject.projectFormat, .pbxproj)
    }

    func testGeneratesXCProjProjectFormat() throws {
        let project = Project(name: "test", options: SpecOptions(projectFileFormat: "xcproj"))
        XCTAssertEqual(project.projectFileFormat, .xcproj)
        XCTAssertEqual(project.projectFormat, .xcode27_0)
        let xcodeProject = try ProjectGenerator(project: project).generateXcodeProject(userName: "someUser")
        XCTAssertEqual(xcodeProject.projectFormat, .xcproj)
    }

    func testProjectFilePath() {
        let projectPath = Path("Folder/App.xcodeproj")
        XCTAssertEqual(ProjectFileFormat.pbxproj.projectFilePath(in: projectPath), Path("Folder/App.xcodeproj/project.pbxproj"))
        XCTAssertEqual(ProjectFileFormat.xcproj.projectFilePath(in: projectPath), Path("Folder/App.xcodeproj/project.xcproj"))
    }

    func testWritesXCProj() throws {
        let project = try makeProject(spec: xcprojSpec, files: ["Sources/a.swift"])
        let projectPath = project.defaultProjectPath
        try write(project)

        XCTAssertTrue((projectPath + "project.xcproj").exists)
        XCTAssertFalse((projectPath + "project.pbxproj").exists)
        XCTAssertTrue((projectPath + "project.xcworkspace/contents.xcworkspacedata").exists)
        XCTAssertTrue((projectPath + "xcshareddata/xcschemes/App.xcscheme").exists)

        let readProject = try XcodeProj(path: projectPath)
        XCTAssertEqual(readProject.projectFormat, .xcproj)
        XCTAssertEqual(readProject.pbxproj.nativeTargets.map(\.name), ["App"])
        XCTAssertEqual(readProject.sharedData?.schemes.map(\.name), ["App"])
    }

    func testWritingXCProjTwiceIsByteIdentical() throws {
        let project = try makeProject(spec: xcprojSpec, files: ["Sources/a.swift"])
        let projectFilePath = project.projectFileFormat.projectFilePath(in: project.defaultProjectPath)
        try write(project)
        let first: Data = try projectFilePath.read()
        try write(project)
        let second: Data = try projectFilePath.read()
        XCTAssertEqual(first, second)
    }

    func testSwitchingProjectFileFormatRemovesOtherProjectFile() throws {
        let pbxprojProject = try makeProject(spec: xcprojSpec.replacingOccurrences(of: "projectFileFormat: xcproj", with: "projectFileFormat: pbxproj"), files: ["Sources/a.swift"])
        let xcprojProject = try Project(path: pbxprojProject.basePath + "xcproj.yml")
        let projectPath = pbxprojProject.defaultProjectPath

        for project in [xcprojProject, pbxprojProject, xcprojProject] {
            try write(project)
            let projectFiles = try projectPath.children().map(\.lastComponent).filter { $0.hasPrefix("project.") && $0 != "project.xcworkspace" }
            XCTAssertEqual(projectFiles, [project.projectFileFormat.projectFilePath(in: projectPath).lastComponent])
            XCTAssertEqual(try XcodeProj(path: projectPath).projectFormat, project.projectFileFormat == .xcproj ? .xcproj : .pbxproj)
        }
    }

    func testSwitchingProjectFileFormatKeepsUserData() throws {
        let project = try makeProject(spec: xcprojSpec.replacingOccurrences(of: "projectFileFormat: xcproj", with: "projectFileFormat: pbxproj"), files: ["Sources/a.swift"])
        let projectPath = project.defaultProjectPath
        try write(project)

        let userStatePath = projectPath + "project.xcworkspace/xcuserdata/someUser.xcuserdatad/UserInterfaceState.xcuserstate"
        try userStatePath.parent().mkpath()
        try userStatePath.write("state")

        try write(Project(path: project.basePath + "xcproj.yml"))
        XCTAssertTrue((projectPath + "project.xcproj").exists)
        XCTAssertEqual(try userStatePath.read(), "state")
    }

    func testExternalProjectReferenceInXCProjFormat() throws {
        let basePath = try Path.processUniqueTemporary() + "ExternalReference"
        try createFiles(["External/Sources/a.swift", "App/Sources/a.swift"], in: basePath)
        try (basePath + "External/project.yml").write("""
        name: External
        options:
          projectFileFormat: xcproj
        targets:
          ExternalFramework:
            type: framework
            platform: iOS
            sources: [Sources]
        """)
        try (basePath + "App/project.yml").write("""
        name: App
        projectReferences:
          External:
            path: ../External/External.xcodeproj
        targets:
          App:
            type: application
            platform: iOS
            sources: [Sources]
            dependencies:
              - target: External/ExternalFramework
        schemes:
          App:
            build:
              targets:
                App: all
                External/ExternalFramework: all
        """)

        let external = try Project(path: basePath + "External/project.yml")
        try write(external)
        let externalTarget = try XCTUnwrap(XcodeProj(path: external.defaultProjectPath).pbxproj.nativeTargets.first)
        XCTAssertEqual(externalTarget.name, "ExternalFramework")

        let app = try Project(path: basePath + "App/project.yml")
        try app.validate()
        let xcodeProject = try ProjectGenerator(project: app).generateXcodeProject(userName: "someUser")

        let proxy = try XCTUnwrap(xcodeProject.pbxproj.containerItemProxies.first { $0.remoteInfo == "ExternalFramework" && $0.proxyType == .nativeTarget })
        XCTAssertEqual(proxy.remoteGlobalID, .string(externalTarget.uuid))

        let scheme = try XCTUnwrap(xcodeProject.sharedData?.schemes.first { $0.name == "App" })
        let buildableReferences = scheme.buildAction?.buildActionEntries.map(\.buildableReference) ?? []
        let externalReference = try XCTUnwrap(buildableReferences.first { $0.blueprintName == "ExternalFramework" })
        XCTAssertEqual(externalReference.blueprintIdentifier, externalTarget.uuid)
        XCTAssertEqual(externalReference.referencedContainer, "container:../External/External.xcodeproj")
    }

    // MARK: - Helpers

    private let xcprojSpec = """
    name: App
    options:
      projectFileFormat: xcproj
    targets:
      App:
        type: application
        platform: iOS
        sources: [Sources]
        scheme: {}
    """

    /// Creates the files of a project in a temporary directory and loads its spec. An `xcproj.yml` spec that generates the same project in the xcproj format is written next to it
    private func makeProject(spec: String, files: [String], contents: [String: String] = [:]) throws -> Project {
        let basePath = try Path.processUniqueTemporary() + name.filter { $0.isLetter || $0.isNumber }
        try createFiles(files, in: basePath, contents: contents)
        try (basePath + "project.yml").write(spec)
        try (basePath + "xcproj.yml").write("""
        include: [project.yml]
        options:
          projectFileFormat: xcproj
        """)
        return try Project(path: basePath + "project.yml")
    }

    private func createFiles(_ files: [String], in basePath: Path, contents: [String: String] = [:]) throws {
        try? basePath.delete()
        for file in files {
            let path = basePath + file
            try path.parent().mkpath()
            try path.write(contents[file] ?? "")
        }
    }

    private func write(_ project: Project) throws {
        let xcodeProject = try ProjectGenerator(project: project).generateXcodeProject(userName: "someUser")
        try FileWriter(project: project).writeXcodeProject(xcodeProject)
    }

    private func generatePBXProj(_ project: Project) throws -> PBXProj {
        try ProjectGenerator(project: project).generateXcodeProject(userName: "someUser").pbxproj
    }

    private func roundTrip(_ pbxproj: PBXProj, name: String) throws -> PBXProj {
        try PBXProj(xcprojData: pbxproj.xcprojData(), projectName: name)
    }
}
