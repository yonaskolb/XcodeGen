import Yams
import XCTest
import Spectre
import PathKit
import XcodeProj
import ProjectSpec
import XcodeGenKit
import TestSupport

extension Project {

    func generateXcodeProject(validate: Bool = true, file: String = #file, line: Int = #line) throws -> XcodeProj {
        try doThrowing(file: file, line: line) {
            if validate {
                try self.validate()
            }
            let generator = ProjectGenerator(project: self)
            return try generator.generateXcodeProject()
        }
    }

    func generatePbxProj(specValidate: Bool = true, projectValidate: Bool = true, file: String = #file, line: Int = #line) throws -> PBXProj {
        try doThrowing(file: file, line: line) {
            let xcodeProject = try generateXcodeProject(validate: specValidate).pbxproj
            if projectValidate {
                try xcodeProject.validate()
            }
            return xcodeProject
        }
    }

}

extension PBXProj {

    // validates that a PBXProj is correct
    // TODO: Use xclint?
    func validate() throws {
        let mainGroup = try getMainGroup()

        func validateGroup(_ group: PBXGroup) throws {

            // check for duplicte children
            let dictionary = Dictionary(grouping: group.children) { $0.hashValue }
            let mostChildren = dictionary.sorted { $0.value.count > $1.value.count }
            if let first = mostChildren.first, first.value.count > 1 {
                throw failure("Group \"\(group.nameOrPath)\" has duplicated children:\n - \(group.children.map { $0.nameOrPath }.joined(separator: "\n - "))")
            }
            for child in group.children {
                if let group = child as? PBXGroup {
                    try validateGroup(group)
                }
            }
        }
        try validateGroup(mainGroup)
    }

    func getMainGroup(function: String = #function, file: String = #file, line: Int = #line) throws -> PBXGroup {
        guard let mainGroup = projects.first?.mainGroup else {
            throw failure("Couldn't find main group", file: file, line: line)
        }
        return mainGroup
    }

}

class PBXProjGeneratorTests: XCTestCase {

    func testGroupOrdering() {
        describe {
            let directoryPath = Path("TestDirectory")

            func createDirectories(_ directories: String) throws {
                let yaml = try Yams.load(yaml: directories)!

                func getFiles(_ file: Any, path: Path) -> [Path] {
                    if let array = file as? [Any] {
                        return array.flatMap { getFiles($0, path: path) }
                    } else if let string = file as? String {
                        return [path + string]
                    } else if let dictionary = file as? [String: Any] {
                        var array: [Path] = []
                        for (key, value) in dictionary {
                            array += getFiles(value, path: path + key)
                        }
                        return array
                    } else {
                        return []
                    }
                }

                let files = getFiles(yaml, path: directoryPath).filter { $0.extension != nil }
                for file in files {
                    try file.parent().mkpath()
                    try file.write("")
                }
            }

            func removeDirectories() {
                try? directoryPath.delete()
            }

            $0.before {
                removeDirectories()
            }

            $0.after {
                removeDirectories()
            }

            $0.it("setups group ordering with groupSortPosition = .top") {
                var options = SpecOptions()
                options.groupSortPosition = .top
                options.groupOrdering = [
                    GroupOrdering(
                        order: [
                            "Sources",
                            "Resources",
                            "Tests",
                            "Support files",
                            "Configurations",
                        ]
                    ),
                    GroupOrdering(
                        pattern: "^.*Screen$",
                        order: [
                            "View",
                            "Presenter",
                            "Interactor",
                            "Entities",
                            "Assembly",
                        ]
                    ),
                ]

                let directories = """
                    Configurations:
                      - file.swift
                    Resources:
                      - file.swift
                    Sources:
                      - MainScreen:
                        - mainScreen1.swift
                        - mainScreen2.swift
                        - Assembly:
                            - file.swift
                        - Entities:
                            - file.swift
                        - Interactor:
                            - file.swift
                        - Presenter:
                            - file.swift
                        - View:
                            - file.swift
                    Support files:
                      - file.swift
                    Tests:
                      - file.swift
                    UITests:
                      - file.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)
                let projGenerator = PBXProjGenerator(project: project)

                let pbxProj = try project.generatePbxProj()
                let group = try pbxProj.getMainGroup()

                projGenerator.setupGroupOrdering(group: group)

                let mainGroups = group.children.map { $0.nameOrPath }
                try expect(mainGroups) == ["Sources", "Resources", "Tests", "Support files", "Configurations", "UITests", "Products"]

                let screenGroups = group.children
                    .first { $0.nameOrPath == "Sources" }
                    .flatMap { $0 as? PBXGroup }?
                    .children
                    .first { $0.nameOrPath == "MainScreen" }
                    .flatMap { $0 as? PBXGroup }?
                    .children
                    .map { $0.nameOrPath }
                try expect(screenGroups) == ["View", "Presenter", "Interactor", "Entities", "Assembly", "mainScreen1.swift", "mainScreen2.swift"]
            }

            $0.it("setups group ordering with groupSortPosition = .bottom") {
                var options = SpecOptions()
                options.groupSortPosition = .bottom
                options.groupOrdering = [
                    GroupOrdering(
                        order: [
                            "Sources",
                            "Resources",
                            "Tests",
                            "Support files",
                            "Configurations",
                        ]
                    ),
                    GroupOrdering(
                        pattern: "^.*Screen$",
                        order: [
                            "View",
                            "Presenter",
                            "Interactor",
                            "Entities",
                            "Assembly",
                        ]
                    ),
                ]

                let directories = """
                    Configurations:
                      - file.swift
                    Resources:
                      - file.swift
                    Sources:
                      - MainScreen:
                        - mainScreen1.swift
                        - mainScreen2.swift
                        - Assembly:
                            - file.swift
                        - Entities:
                            - file.swift
                        - Interactor:
                            - file.swift
                        - Presenter:
                            - file.swift
                        - View:
                            - file.swift
                    Support files:
                      - file.swift
                    Tests:
                      - file.swift
                    UITests:
                      - file.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)
                let projGenerator = PBXProjGenerator(project: project)

                let pbxProj = try project.generatePbxProj()
                let group = try pbxProj.getMainGroup()

                projGenerator.setupGroupOrdering(group: group)

                let mainGroups = group.children.map { $0.nameOrPath }
                try expect(mainGroups) == ["Sources", "Resources", "Tests", "Support files", "Configurations", "UITests", "Products"]

                let screenGroups = group.children
                    .first { $0.nameOrPath == "Sources" }
                    .flatMap { $0 as? PBXGroup }?
                    .children
                    .first { $0.nameOrPath == "MainScreen" }
                    .flatMap { $0 as? PBXGroup }?
                    .children
                    .map { $0.nameOrPath }
                try expect(screenGroups) == ["mainScreen1.swift", "mainScreen2.swift", "View", "Presenter", "Interactor", "Entities", "Assembly"]
            }
        }
    }
    
    func testDefaultLastUpgradeCheckWhenUserDidSpecifyInvalidValue() throws {
        let lastUpgradeKey = "LastUpgradeCheck"
        let attributes: [String: Any] = [lastUpgradeKey: 1234]
        let project = Project(name: "Test", attributes: attributes)
        let projGenerator = PBXProjGenerator(project: project)
        
        let pbxProj = try projGenerator.generate()
        
        for pbxProject in pbxProj.projects {
            XCTAssertEqual(pbxProject.attributes[lastUpgradeKey] as? String, project.xcodeVersion)
        }
    }
    
    func testOverrideLastUpgradeCheckWhenUserDidSpecifyValue() throws {
        let lastUpgradeKey = "LastUpgradeCheck"
        let lastUpgradeValue = "1234"
        let attributes: [String: Any] = [lastUpgradeKey: lastUpgradeValue]
        let project = Project(name: "Test", attributes: attributes)
        let projGenerator = PBXProjGenerator(project: project)
        
        let pbxProj = try projGenerator.generate()
        
        for pbxProject in pbxProj.projects {
            XCTAssertEqual(pbxProject.attributes[lastUpgradeKey] as? String, lastUpgradeValue)
        }
    }
    
    func testDefaultLastUpgradeCheckWhenUserDidNotSpecifyValue() throws {
        let lastUpgradeKey = "LastUpgradeCheck"
        let project = Project(name: "Test")
        let projGenerator = PBXProjGenerator(project: project)
        
        let pbxProj = try projGenerator.generate()
        
        for pbxProject in pbxProj.projects {
            XCTAssertEqual(pbxProject.attributes[lastUpgradeKey] as? String, project.xcodeVersion)
        }
    }

    func testPlatformDependencies() {
        describe {
            let directoryPath = Path("TestDirectory")

            func createDirectories(_ directories: String) throws {
                let yaml = try Yams.load(yaml: directories)!

                func getFiles(_ file: Any, path: Path) -> [Path] {
                    if let array = file as? [Any] {
                        return array.flatMap { getFiles($0, path: path) }
                    } else if let string = file as? String {
                        return [path + string]
                    } else if let dictionary = file as? [String: Any] {
                        var array: [Path] = []
                        for (key, value) in dictionary {
                            array += getFiles(value, path: path + key)
                        }
                        return array
                    } else {
                        return []
                    }
                }

                let files = getFiles(yaml, path: directoryPath).filter { $0.extension != nil }
                for file in files {
                    try file.parent().mkpath()
                    try file.write("")
                }
            }

            func removeDirectories() {
                try? directoryPath.delete()
            }

            $0.before {
                removeDirectories()
            }

            $0.after {
                removeDirectories()
            }

            $0.it("setups target with different dependencies") {
                let directories = """
                    Sources:
                      - MainScreen:
                        - Entities:
                            - file.swift
                """
                try createDirectories(directories)
                let target1 = Target(name: "TestAll", type: .application, platform: .iOS, sources: ["Sources"])
                let target2 = Target(name: "TestiOS", type: .application, platform: .iOS, sources: ["Sources"])
                let target3 = Target(name: "TestmacOS", type: .application, platform: .iOS, sources: ["Sources"])
                let dependency1 = Dependency(type: .target, reference: "TestAll", platform: .all)
                let dependency2 = Dependency(type: .target, reference: "TestiOS", platform: .iOS)
                let dependency3 = Dependency(type: .target, reference: "TestmacOS", platform: .macOS)
                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"], dependencies: [dependency1, dependency2, dependency3])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target, target1, target2, target3])

                let pbxProj = try project.generatePbxProj()

                let targets = pbxProj.projects.first?.targets
                let testTargetDependencies = pbxProj.projects.first?.targets.first(where: { $0.name == "Test" })?.dependencies
                try expect(targets?.count) == 4
                try expect(testTargetDependencies?.count) == 3
                try expect(testTargetDependencies?[0].platformFilter).beNil()
                try expect(testTargetDependencies?[1].platformFilter) == "ios"
                try expect(testTargetDependencies?[2].platformFilter) == "maccatalyst"
            }
        }
    }
}
