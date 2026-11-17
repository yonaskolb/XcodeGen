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
        for spec in specs {
            let project = try Project(path: fixturePath + spec)
            try assertRoundTrip(project, message: spec)
        }
    }

    func testRoundTripCoversFixtureFeatures() throws {
        try skipIfNecessary()
        let project = try Project(path: fixturePath + "TestProject/project.yml")
        let lines = try ProjectSummary(generatePBXProj(project)).lines

        // make sure the fixture round trip exercises the parts of a project most likely to be lost in conversion
        let features = [
            "kind=PBXLegacyTarget",
            "kind=PBXAggregateTarget",
            "file PBXVariantGroup",
            "file PBXFileSystemSynchronizedRootGroup",
            "exception target=",
            "platformFilters=[\"ios\"]",
            "CopyFiles name=",
            "Run Script name=",
            "inputFileLists=[\"",
            "Headers",
            "COMPILER_FLAGS=",
            "ATTRIBUTES=",
            "ASSET_TAGS=",
            "remote package",
            "project reference",
            "attribute ProvisioningStyle=Automatic",
            "attribute TestTargetID=",
            "base=",
        ]
        for feature in features {
            XCTAssertTrue(lines.contains { $0.contains(feature) }, "TestProject no longer contains \(feature)")
        }
    }

    func testProjectSummaryDetectsChanges() throws {
        try skipIfNecessary()
        let project = try Project(path: fixturePath + "TestProject/project.yml")
        let original = try ProjectSummary(generatePBXProj(project)).lines

        // each change is made to a fresh copy of the project, and must show up in its summary
        let changes: [(String, (PBXProj) throws -> Void)] = [
            ("build setting", { try XCTUnwrap($0.buildConfigurations.first).buildSettings["NEW_SETTING"] = "YES" }),
            ("base configuration", { pbxproj in
                let configuration = try XCTUnwrap(pbxproj.buildConfigurations.first { $0.baseConfiguration != nil })
                configuration.baseConfiguration = try XCTUnwrap(pbxproj.fileReferences.first { $0.path == "Info.plist" })
            }),
            ("build file", { try XCTUnwrap($0.sourcesBuildPhases.first { !($0.files ?? []).isEmpty }).files?.removeLast() }),
            ("build file setting", { try XCTUnwrap($0.buildFiles.first { $0.settings != nil }).settings = nil }),
            ("build file platform filter", { try XCTUnwrap($0.buildFiles.first { $0.platformFilters != nil }).platformFilters?.append("xros") }),
            ("target dependency", { try XCTUnwrap($0.nativeTargets.first { !$0.dependencies.isEmpty }).dependencies.removeLast() }),
            ("product type", { try XCTUnwrap($0.nativeTargets.first { $0.productType == .framework }).productType = .staticFramework }),
            ("script", { try XCTUnwrap($0.shellScriptBuildPhases.first).shellScript = "changed" }),
            ("copy files destination", { try XCTUnwrap($0.copyFilesBuildPhases.first).dstPath = "changed" }),
            ("group child", { try XCTUnwrap($0.rootObject?.mainGroup.children.first as? PBXGroup).children.removeLast() }),
            ("file path", { try XCTUnwrap($0.fileReferences.first { $0.path == "Info.plist" }).path = "Changed.plist" }),
            ("synchronized folder exception", { try XCTUnwrap($0.fileSystemSynchronizedBuildFileExceptionSets.first { !($0.membershipExceptions ?? []).isEmpty }).membershipExceptions = [] }),
            ("synchronized folder platform filter", { try XCTUnwrap($0.fileSystemSynchronizedBuildFileExceptionSets.first { $0.platformFiltersByRelativePath != nil }).platformFiltersByRelativePath = [:] }),
            ("package version", { try XCTUnwrap($0.rootObject?.remotePackages.first).versionRequirement = .exact("0.0.1") }),
            ("target attribute", { pbxproj in
                let project = try XCTUnwrap(pbxproj.rootObject)
                let target = try XCTUnwrap(project.targetAttributes.first { $0.value["ProvisioningStyle"] != nil }?.key)
                project.setTargetAttributes(["ProvisioningStyle": .string("Manual")], target: target)
            }),
        ]
        for (change, apply) in changes {
            let pbxproj = try generatePBXProj(project)
            try apply(pbxproj)
            XCTAssertNotEqual(ProjectSummary(pbxproj).lines, original, "a changed \(change) wasn't detected")
        }
    }

    func testBuildRulesRoundTrip() throws {
        let project = try makeProject(spec: """
        name: Rules
        targets:
          Framework:
            type: framework
            platform: iOS
            sources: [Sources]
            buildRules:
              - name: Generate
                filePattern: "*.xyz"
                script: generate "$INPUT_FILE_PATH"
                inputFiles: [$(SRCROOT)/tool]
                outputFiles: [$(DERIVED_FILE_DIR)/$(INPUT_FILE_BASE).swift]
                outputFilesCompilerFlags: [-Werror]
                runOncePerArchitecture: false
              - fileType: sourcecode.metal
                compilerSpec: com.apple.compilers.metal
        """, files: ["Sources/a.swift", "Sources/b.xyz"])

        let lines = try assertRoundTrip(project)
        XCTAssertTrue(lines.contains { $0.contains("build rule name=Generate") && $0.contains("filePatterns=*.xyz") })
        XCTAssertTrue(lines.contains { $0.contains("fileType=sourcecode.metal") })
    }

    func testCoreDataModelRoundTrip() throws {
        let project = try makeProject(spec: """
        name: CoreData
        targets:
          App:
            type: application
            platform: iOS
            sources: [Sources]
        """, files: [
            "Sources/Model.xcdatamodeld/Model.xcdatamodel/contents",
            "Sources/Model.xcdatamodeld/Model 2.xcdatamodel/contents",
            "Sources/Model.xcdatamodeld/.xccurrentversion",
        ], contents: [
            "Sources/Model.xcdatamodeld/.xccurrentversion": """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>_XCCurrentVersionName</key>
                <string>Model 2.xcdatamodel</string>
            </dict>
            </plist>
            """,
        ])

        let lines = try assertRoundTrip(project)
        XCTAssertTrue(lines.contains { $0.contains("file XCVersionGroup Sources/Model.xcdatamodeld") && $0.contains("current=Sources/Model.xcdatamodeld/Model 2.xcdatamodel") })
    }

    func testSyncedFolderRoundTrip() throws {
        let project = try makeProject(spec: """
        name: Synced
        targets:
          App:
            type: application
            supportedDestinations: [iOS, tvOS]
            sources:
              - path: Sources
                type: syncedFolder
                excludes: [Excluded.swift]
              - path: Sources/iOS.swift
                destinationFilters: [iOS]
              - path: Sources/tvOS.swift
                destinationFilters: [tvOS]
          Framework:
            type: framework
            platform: iOS
            sources:
              - path: Shared
                type: syncedFolder
          OtherFramework:
            type: framework
            platform: iOS
            sources:
              - path: Shared
                type: syncedFolder
        """, files: ["Sources/a.swift", "Sources/Excluded.swift", "Sources/iOS.swift", "Sources/tvOS.swift", "Shared/shared.swift"])

        let lines = try assertRoundTrip(project)
        XCTAssertTrue(lines.contains { $0.contains("target App synchronized folder Sources") })
        XCTAssertTrue(lines.contains { $0.contains("target Framework synchronized folder Shared") })
        XCTAssertTrue(lines.contains { $0.contains("target OtherFramework synchronized folder Shared") })
        XCTAssertTrue(lines.contains { $0.contains("exception target=App") && $0.contains("Excluded.swift") })
    }

    func testFileSettingsRoundTrip() throws {
        let project = try makeProject(spec: """
        name: FileSettings
        targets:
          Framework:
            type: framework
            platform: iOS
            sources:
              - path: Sources
                compilerFlags: [-Werror, -Wall]
              - path: Headers
                headerVisibility: public
              - path: Private
                headerVisibility: private
              - path: Resources
                resourceTags: [tag1, tag2]
          App:
            type: application
            supportedDestinations: [iOS, macOS]
            sources: [App]
            dependencies:
              - target: Framework
                destinationFilters: [iOS]
                weak: true
              - sdk: Contacts.framework
              - sdk: libz.tbd
        """, files: ["Sources/a.swift", "Sources/b.m", "Headers/Public.h", "Private/Private.h", "Resources/image.png", "App/main.swift"])

        let lines = try assertRoundTrip(project)
        XCTAssertTrue(lines.contains { $0.contains("Sources/b.m") && $0.contains("COMPILER_FLAGS=") })
        XCTAssertTrue(lines.contains { $0.contains("Headers/Public.h") && $0.contains("Public") })
        XCTAssertTrue(lines.contains { $0.contains("Private/Private.h") && $0.contains("Private") })
        XCTAssertTrue(lines.contains { $0.contains("Resources/image.png") && $0.contains("ASSET_TAGS=") })
        XCTAssertTrue(lines.contains { $0.contains("dependency Framework") && $0.contains("platformFilters=[\"ios\"]") })
        XCTAssertTrue(lines.contains { $0.contains("Framework.framework") && $0.contains("Weak") })
        XCTAssertTrue(lines.contains { $0.contains("Contacts.framework") })
    }

    func testPackagesRoundTrip() throws {
        let project = try makeProject(spec: """
        name: Packages
        packages:
          Yams:
            url: https://github.com/jpsim/Yams
            from: 5.0.0
          Branch:
            url: https://github.com/example/Branch
            branch: main
          Revision:
            url: https://github.com/example/Revision
            revision: abcdef
          Range:
            url: https://github.com/example/Range
            minVersion: 1.0.0
            maxVersion: 2.0.0
          Exact:
            url: https://github.com/example/Exact
            exactVersion: 1.2.3
          Local:
            path: Local
        targets:
          App:
            type: application
            platform: iOS
            sources: [Sources]
            dependencies:
              - package: Yams
              - package: Branch
              - package: Revision
              - package: Range
              - package: Exact
              - package: Local
                products: [LocalA, LocalB]
        """, files: ["Sources/a.swift", "Local/Package.swift"])

        let lines = try assertRoundTrip(project)
        XCTAssertEqual(lines.filter { $0.hasPrefix("remote package") }.count, 5)
        XCTAssertEqual(lines.filter { $0.hasPrefix("local package") }.count, 1)
        XCTAssertTrue(lines.contains { $0.contains("package product LocalB") })
    }

    func testTargetAttributesInXCProj() throws {
        let project = try makeProject(spec: """
        name: Attributes
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

        let lines = try ProjectSummary(roundTrip(generatePBXProj(project), name: project.name)).lines
        XCTAssertTrue(lines.contains("target App attribute DevelopmentTeam=ABCDEF"))
        XCTAssertTrue(lines.contains("target App attribute ProvisioningStyle=Manual"))
        XCTAssertTrue(lines.contains("target UITests attribute TestTargetID=App"))
        // the xcproj format has no place for arbitrary target attributes, which is documented in ProjectSpec.md
        XCTAssertFalse(lines.contains { $0.contains("CUSTOM") })
    }

    func testXCProjDataIsDeterministic() throws {
        let project = try Project(path: fixturePath + "TestProject/project.yml")
        let first = try generatePBXProj(project).xcprojData()
        let second = try generatePBXProj(project).xcprojData()
        XCTAssertEqual(first, second)
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

    /// Asserts that a project keeps everything Xcode uses when stored as a project.xcproj and read back
    @discardableResult
    private func assertRoundTrip(_ project: Project, message: String = "", file: StaticString = #filePath, line: UInt = #line) throws -> Set<String> {
        let pbxproj = try generatePBXProj(project)
        let expected = ProjectSummary(pbxproj).lines
        let actual = try ProjectSummary(roundTrip(pbxproj, name: project.name)).lines
        let missing = expected.subtracting(actual).sorted()
        let added = actual.subtracting(expected).sorted()
        XCTAssertTrue(missing.isEmpty && added.isEmpty, """
        \(message) changed in the xcproj round trip
        missing:
        \(missing.joined(separator: "\n"))
        added:
        \(added.joined(separator: "\n"))
        """, file: file, line: line)
        return expected
    }
}

/// A description of the parts of a project that Xcode uses, independent of object identifiers and of the order objects are stored in.
///
/// It leaves out what the xcproj format doesn't store or stores differently without changing the project:
/// - project and target attributes that the format has no place for, such as `knownAssetTags` (Xcode derives these from the files' asset tags) and arbitrary target attributes
/// - `BuildIndependentTargetsInParallel = YES`, which is the format's default
/// - the difference between `platformFilter` and a `platformFilters` array with a single platform
/// - the build tool plugins that XcodeProj also lists in `packageProductDependencies` when reading a project.xcproj
struct ProjectSummary {

    private(set) var lines: Set<String> = []
    private var paths: [ObjectIdentifier: String] = [:]

    private static let targetAttributes: Set<String> = ["DevelopmentTeam", "ProvisioningStyle", "TestTargetID", "LastSwiftMigration"]

    init(_ pbxproj: PBXProj) {
        guard let project = pbxproj.rootObject else {
            lines.insert("missing root object")
            return
        }
        add("project developmentRegion=\(project.developmentRegion ?? "")")
        add("project knownRegions=\(project.knownRegions.sorted())")
        add("project BuildIndependentTargetsInParallel=\(project.attributes["BuildIndependentTargetsInParallel"]?.stringValue ?? "YES")")
        if let lastUpgradeCheck = project.attributes["LastUpgradeCheck"] {
            add("project LastUpgradeCheck=\(describe(lastUpgradeCheck))")
        }
        for package in project.remotePackages {
            add("remote package \(package.repositoryURL ?? "") \(package.versionRequirement.map { "\($0)" } ?? "") traits=\(package.traits ?? [])")
        }
        for package in project.localPackages {
            add("local package \(package.relativePath) traits=\(package.traits ?? [])")
        }
        if let mainGroup = project.mainGroup {
            add(element: mainGroup, parentPath: "")
        }
        for reference in project.projects {
            add("project reference \(reference["ProjectRef"].map(path) ?? "")")
        }
        add(configurationList: project.buildConfigurationList, owner: "project")
        for target in project.targets {
            add(target: target, project: project)
        }
    }

    private mutating func add(_ line: String) {
        lines.insert(line)
    }

    private mutating func add(configurationList: XCConfigurationList?, owner: String) {
        guard let configurationList else { return }
        add("\(owner) defaultConfiguration=\(configurationList.defaultConfigurationName ?? "")")
        for configuration in configurationList.buildConfigurations {
            add("\(owner) config \(configuration.name) base=\(configuration.baseConfiguration.map(path) ?? "") baseAnchor=\(configuration.baseConfigurationAnchor.map(path) ?? "") baseRelativePath=\(configuration.baseConfigurationReferenceRelativePath ?? "")")
            for (key, value) in configuration.buildSettings {
                add("\(owner) config \(configuration.name) \(key)=\(value)")
            }
        }
    }

    private mutating func add(element: PBXFileElement, parentPath: String) {
        let elementPath = [parentPath, element.path ?? element.name ?? ""].filter { !$0.isEmpty }.joined(separator: "/")
        paths[ObjectIdentifier(element)] = elementPath

        var line = "file \(type(of: element)) \(elementPath) sourceTree=\(element.sourceTree.map { "\($0)" } ?? "")"
        if let reference = element as? PBXFileReference {
            line += " explicitFileType=\(reference.explicitFileType ?? "") includeInIndex=\(reference.includeInIndex.map { "\($0)" } ?? "")"
        }
        if let folder = element as? PBXFileSystemSynchronizedRootGroup {
            line += " explicitFileTypes=\((folder.explicitFileTypes ?? [:]).sorted { $0.key < $1.key }) explicitFolders=\((folder.explicitFolders ?? []).sorted())"
            for exception in folder.exceptions ?? [] {
                add("\(elementPath) exception \(describe(exception))")
            }
        }
        if let group = element as? PBXGroup {
            for child in group.children {
                add(element: child, parentPath: elementPath)
            }
            add("group \(elementPath) children=\(group.children.map(path))")
        }
        if let versionGroup = element as? XCVersionGroup {
            line += " current=\(versionGroup.currentVersion.map(path) ?? "") type=\(versionGroup.versionGroupType ?? "")"
        }
        add(line)
    }

    private mutating func add(target: PBXTarget, project: PBXProject) {
        let owner = "target \(target.name)"
        add("\(owner) kind=\(type(of: target)) productType=\(target.productType?.rawValue ?? "")")
        if let legacyTarget = target as? PBXLegacyTarget {
            add("\(owner) buildTool=\(legacyTarget.buildToolPath ?? "") arguments=\(legacyTarget.buildArgumentsString ?? "") workingDirectory=\(legacyTarget.buildWorkingDirectory ?? "") passBuildSettings=\(legacyTarget.passBuildSettingsInEnvironment)")
        }
        add(configurationList: target.buildConfigurationList, owner: owner)
        for (key, value) in project.targetAttributes[target] ?? [:] where Self.targetAttributes.contains(key) {
            add("\(owner) attribute \(key)=\(describe(value))")
        }
        for (index, phase) in target.buildPhases.enumerated() {
            add(phase: phase, index: index, owner: owner)
        }
        for rule in target.buildRules {
            add("\(owner) build rule name=\(rule.name ?? "") compilerSpec=\(rule.compilerSpec) fileType=\(rule.fileType) filePatterns=\(rule.filePatterns ?? "") script=\(rule.script ?? "") inputFiles=\(rule.inputFiles ?? []) outputFiles=\(rule.outputFiles) outputFilesCompilerFlags=\(rule.outputFilesCompilerFlags ?? []) runOncePerArchitecture=\(rule.runOncePerArchitecture.map { "\($0)" } ?? "")")
        }
        for dependency in target.dependencies {
            let destination = dependency.target?.name ?? dependency.targetProxy?.remoteInfo ?? dependency.product.map(describe) ?? ""
            add("\(owner) dependency \(destination) platformFilters=\(platformFilters(dependency.platformFilter, dependency.platformFilters))")
        }
        // package products that targets depend on directly are build tool plugins
        let pluginNames = Set(target.dependencies.compactMap(\.product?.productName))
        for product in target.packageProductDependencies ?? [] where !pluginNames.contains(product.productName) {
            add("\(owner) package product \(describe(product))")
        }
        for folder in target.fileSystemSynchronizedGroups ?? [] {
            add("\(owner) synchronized folder \(path(folder))")
        }
    }

    private mutating func add(phase: PBXBuildPhase, index: Int, owner: String) {
        var description = "\(phase.buildPhase.rawValue)"
        if let copyFiles = phase as? PBXCopyFilesBuildPhase {
            description += " name=\(copyFiles.name ?? "") dstPath=\(copyFiles.dstPath ?? "") dstSubfolder=\(copyFiles.dstSubfolder.map { "\($0)" } ?? "")"
        }
        if let script = phase as? PBXShellScriptBuildPhase {
            description += " name=\(script.name ?? "") shellPath=\(script.shellPath ?? "") shellScript=\(script.shellScript ?? "") inputPaths=\(script.inputPaths) outputPaths=\(script.outputPaths) showEnvVars=\(script.showEnvVarsInLog) alwaysOutOfDate=\(script.alwaysOutOfDate) dependencyFile=\(script.dependencyFile ?? "")"
        }
        description += " inputFileLists=\(phase.inputFileListPaths ?? []) outputFileLists=\(phase.outputFileListPaths ?? []) deploymentPostprocessing=\(phase.runOnlyForDeploymentPostprocessing)"
        add("\(owner) phase \(index) \(description)")
        for file in phase.files ?? [] {
            let destination = file.file.map(path) ?? file.product.map(describe) ?? ""
            let settings = (file.settings ?? [:]).map { "\($0.key)=\($0.value)" }.sorted()
            add("\(owner) phase \(index) file \(destination) settings=\(settings) platformFilters=\(platformFilters(file.platformFilter, file.platformFilters))")
        }
    }

    private func platformFilters(_ platformFilter: String?, _ platformFilters: [String]?) -> [String] {
        Set((platformFilters ?? []) + [platformFilter].compactMap { $0 }).sorted()
    }

    private func describe(_ exception: PBXFileSystemSynchronizedExceptionSet) -> String {
        if let exception = exception as? PBXFileSystemSynchronizedBuildFileExceptionSet {
            return "target=\(exception.target?.name ?? "") membershipExceptions=\((exception.membershipExceptions ?? []).sorted()) publicHeaders=\((exception.publicHeaders ?? []).sorted()) privateHeaders=\((exception.privateHeaders ?? []).sorted()) compilerFlags=\((exception.additionalCompilerFlagsByRelativePath ?? [:]).sorted { $0.key < $1.key }) attributes=\((exception.attributesByRelativePath ?? [:]).mapValues { $0.sorted() }.sorted { $0.key < $1.key }) platformFilters=\((exception.platformFiltersByRelativePath ?? [:]).mapValues { $0.sorted() }.sorted { $0.key < $1.key })"
        }
        if let exception = exception as? PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet {
            return "buildPhase=\(exception.buildPhase.buildPhase.rawValue) membershipExceptions=\((exception.membershipExceptions ?? []).sorted()) attributes=\((exception.attributesByRelativePath ?? [:]).mapValues { $0.sorted() }.sorted { $0.key < $1.key })"
        }
        return "\(type(of: exception))"
    }

    private func describe(_ product: XCSwiftPackageProductDependency) -> String {
        "\(product.productName) package=\(product.package?.repositoryURL ?? "")"
    }

    private func describe(_ attribute: ProjectAttribute) -> String {
        switch attribute {
        case let .string(value): value
        case let .array(value): "\(value)"
        case let .targetReference(object): (object as? PBXTarget)?.name ?? "\(type(of: object))"
        case let .attributeDictionary(value): "\(value.mapValues { $0.mapValues(describe).sorted { $0.key < $1.key } }.sorted { $0.key < $1.key })"
        }
    }

    /// The location of an element in the groups and files tree, or its own path for elements outside of it, such as the products of referenced projects
    private func path(_ element: PBXFileElement) -> String {
        paths[ObjectIdentifier(element)] ?? "\(type(of: element)) \(element.path ?? element.name ?? "")"
    }
}
