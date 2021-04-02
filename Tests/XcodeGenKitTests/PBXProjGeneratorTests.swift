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

    private func createDirectories(_ directories: String, directoryPath: Path) throws {
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

    private func removeDirectories(directoryPath: Path) {
        try? directoryPath.delete()
    }

    func testGroupOrdering() {
        describe { [weak self] in
            let directoryPath = Path("TestDirectory")

            $0.before { [weak self] in
                self?.removeDirectories(directoryPath: directoryPath)
            }

            $0.after { [weak self] in
                self?.removeDirectories(directoryPath: directoryPath)
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
                try self?.createDirectories(directories, directoryPath: directoryPath)

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
                try self?.createDirectories(directories, directoryPath: directoryPath)

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

    func testGeneratedTargetsOrder() {
        describe { [weak self] in
            let directoryPath = Path("TestDirectory")

            $0.before { [weak self] in
                self?.removeDirectories(directoryPath: directoryPath)
            }

            $0.after { [weak self] in
                self?.removeDirectories(directoryPath: directoryPath)
            }

            $0.it("generates static lib target only after resource bundles target is generated") {

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
                try self?.createDirectories(directories, directoryPath: directoryPath)

                let resourceBundleTarget = Target(name: "Test Resource Bundle", type: .bundle, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"])
                let resourceBundleTarget2 = Target(name: "Test Resource Bundle 2", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget3 = Target(name: "Test Resource Bundle 3", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget4 = Target(name: "Test Resource Bundle 4", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget5 = Target(name: "Test Resource Bundle 5", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleDependency: Dependency = Dependency(type: .target, reference: "Test Resource Bundle")
                let staticLibraryTarget = Target(name: "Test static library", type: .staticLibrary, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"], dependencies: [resourceBundleDependency])
                let project = Project(basePath: directoryPath, name: "Test", targets: [resourceBundleTarget, staticLibraryTarget, resourceBundleTarget2, resourceBundleTarget3, resourceBundleTarget4, resourceBundleTarget5])

                let pbxProj = try project.generatePbxProj()
                guard let allTargets = pbxProj.rootObject?.targets else {
                    XCTFail("Could not get all targets of the project")
                    return
                }

                try expect(allTargets.map { $0.name }) == ["Test Resource Bundle", "Test Resource Bundle 2", "Test Resource Bundle 3", "Test Resource Bundle 4", "Test Resource Bundle 5", "Test static library"]
                try expect(allTargets.first(where: { $0.name == "Test static library" })?.dependencies.first?.target?.name) == "Test Resource Bundle"
            }

            $0.it("generates sequential dependencies in order") {

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
                try self?.createDirectories(directories, directoryPath: directoryPath)

                let resourceBundleTarget = Target(name: "Test Resource Bundle", type: .bundle, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"])
                let resourceBundleTarget2 = Target(name: "Test Resource Bundle 2", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget3 = Target(name: "Test Resource Bundle 3", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget4 = Target(name: "Test Resource Bundle 4", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleTarget5 = Target(name: "Test Resource Bundle 5", type: .bundle, platform: .iOS, sources: ["Resources"])
                let resourceBundleDependency: Dependency = Dependency(type: .target, reference: "Test Resource Bundle")
                let staticLibraryTarget = Target(name: "Test static library", type: .staticLibrary, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"], dependencies: [resourceBundleDependency])
                let project = Project(basePath: directoryPath, name: "Test", targets: [resourceBundleTarget, staticLibraryTarget, resourceBundleTarget2, resourceBundleTarget3, resourceBundleTarget4, resourceBundleTarget5])

                let pbxProj = try project.generatePbxProj()
                guard let allTargets = pbxProj.rootObject?.targets else {
                    XCTFail("Could not get all targets of the project")
                    return
                }

                try expect(allTargets.map { $0.name }) == ["Test Resource Bundle", "Test Resource Bundle 2", "Test Resource Bundle 3", "Test Resource Bundle 4", "Test Resource Bundle 5", "Test static library"]
                try expect(allTargets.first(where: { $0.name == "Test static library" })?.dependencies.first?.target?.name) == "Test Resource Bundle"
            }

            $0.it("generates sequential dependencies in order test 2") {

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
                try self?.createDirectories(directories, directoryPath: directoryPath)

                let resourceBundleTarget = Target(name: "Test Resource Bundle", type: .bundle, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"])
                // 4 <- 3, 3 <- 2, 2 <- 1, staticLibraryTarget <- 4,3,2,1
                let staticLibraryTarget1 = Target(name: "Test Static Library 1", type: .staticLibrary, platform: .iOS, sources: ["Resources"])
                let staticLibraryTarget2Dependencies = Dependency(type: .target, reference: "Test Static Library 1")
                let staticLibraryTarget2 = Target(name: "Test Static Library 2", type: .staticLibrary, platform: .iOS, sources: ["Resources"], dependencies: [staticLibraryTarget2Dependencies])
                let staticLibraryTarget3Dependencies = Dependency(type: .target, reference: "Test Static Library 2")
                let staticLibraryTarget3 = Target(name: "Test Static Library 3", type: .staticLibrary, platform: .iOS, sources: ["Resources"], dependencies: [staticLibraryTarget3Dependencies])
                let staticLibraryTarget4Dependencies = Dependency(type: .target, reference: "Test Static Library 3")
                let staticLibraryTarget4 = Target(name: "Test Static Library 4", type: .staticLibrary, platform: .iOS, sources: ["Resources"], dependencies: [staticLibraryTarget4Dependencies])
                let resourceBundleDependency: Dependency = Dependency(type: .target, reference: "Test Resource Bundle")
                let staticLibraryMainTarget = Target(name: "Test main static library", type: .staticLibrary, platform: .iOS, sources: ["Configurations", "Resources", "Sources", "Support files", "Tests", "UITests"], dependencies: [resourceBundleDependency, staticLibraryTarget4Dependencies, staticLibraryTarget2Dependencies, staticLibraryTarget3Dependencies])
                let project = Project(basePath: directoryPath, name: "Test", targets: [resourceBundleTarget, staticLibraryTarget1, staticLibraryTarget2, staticLibraryTarget3, staticLibraryTarget4, staticLibraryMainTarget])

                let pbxProj = try project.generatePbxProj()
                guard let allTargets = pbxProj.rootObject?.targets else {
                    XCTFail("Could not get all targets of the project")
                    return
                }

                try expect(allTargets.map { $0.name }) == ["Test Resource Bundle", "Test Static Library 1", "Test Static Library 2", "Test Static Library 3", "Test Static Library 4", "Test main static library"]
                try expect(allTargets.first(where: { $0.name == "Test main static library" })?.dependencies.first?.target?.name) == "Test Resource Bundle"
            }
        }
    }

}
