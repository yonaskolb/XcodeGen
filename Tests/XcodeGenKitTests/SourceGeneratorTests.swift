import PathKit
import ProjectSpec
import Spectre
import XcodeGenKit
import xcodeproj
import XCTest
import Yams

class SourceGeneratorTests: XCTestCase {

    func testSourceGenerator() {
        describe {

            let directoryPath = Path("TestDirectory")
            let outOfRootPath = Path("OtherDirectory")

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
                try? outOfRootPath.delete()
            }

            $0.before {
                removeDirectories()
            }

            $0.after {
                removeDirectories()
            }

            $0.it("generates source groups") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - B:
                      - b.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "A", "B", "b.swift"], buildPhase: .sources)
            }

            $0.it("supports frameworks in sources") {
                let directories = """
                Sources:
                  - Foo.framework
                  - Bar.swift
                """

                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "Bar.swift"], buildPhase: .sources)
                let buildPhase = pbxProj.copyFilesBuildPhases.first
                try expect(buildPhase?.dstSubfolderSpec) == .frameworks
                let fileReference = pbxProj.getFileReference(
                    paths: ["Sources", "Foo.framework"],
                    names: ["Sources", "Foo.framework"]
                )
                guard let buildFile = pbxProj.buildFiles
                    .first(where: { $0.file == fileReference }) else {
                    throw failure("Cant find build file")
                }
                try expect(buildPhase?.files.count) == 1
                try expect(buildPhase?.files.contains(buildFile)) == true
            }

            $0.it("generates core data models") {
                let directories = """
                Sources:
                    model.xcdatamodeld:
                        - .xccurrentversion
                        - model.xcdatamodel
                        - model1.xcdatamodel
                        - model2.xcdatamodel
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                guard let fileReference = pbxProj.fileReferences.first(where: { $0.nameOrPath == "model2.xcdatamodel" }) else {
                    throw failure("Couldn't find model file reference")
                }
                guard let versionGroup = pbxProj.versionGroups.first else {
                    throw failure("Couldn't find version group")
                }
                try expect(versionGroup.currentVersion) == fileReference
                try expect(versionGroup.children.count) == 3
                try expect(versionGroup.path) == "model.xcdatamodeld"
                try expect(fileReference.path) == "model2.xcdatamodel"
            }

            $0.it("generates variant groups") {
                let directories = """
                Sources:
                    Base.lproj:
                        - LocalizedStoryboard.storyboard
                    en.lproj:
                        - LocalizedStoryboard.strings
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()

                func getFileReferences(_ path: String) -> [PBXFileReference] {
                    return pbxProj.fileReferences.filter { $0.path == path }
                }

                func getVariableGroups(_ name: String?) -> [PBXVariantGroup] {
                    return pbxProj.variantGroups.filter { $0.name == name }
                }

                let resourceName = "LocalizedStoryboard.storyboard"
                let baseResource = "Base.lproj/LocalizedStoryboard.storyboard"
                let localizedResource = "en.lproj/LocalizedStoryboard.strings"

                guard let variableGroup = getVariableGroups(resourceName).first else { throw failure("Couldn't find the variable group") }

                do {
                    let refs = getFileReferences(baseResource)
                    try expect(refs.count) == 1
                    try expect(variableGroup.children.filter { $0 == refs.first }.count) == 1
                }

                do {
                    let refs = getFileReferences(localizedResource)
                    try expect(refs.count) == 1
                    try expect(variableGroup.children.filter { $0 == refs.first }.count) == 1
                }
            }

            $0.it("handles duplicate names") {
                let directories = """
                Sources:
                  - a.swift
                  - a:
                    - a.swift
                    - a:
                      - a.swift

                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(
                    basePath: directoryPath,
                    name: "Test",
                    targets: [target],
                    fileGroups: ["Sources"]
                )

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "a", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "a", "a", "a.swift"], buildPhase: .sources)
            }

            $0.it("renames sources") {
                let directories = """
                Sources:
                    - a.swift
                OtherSource:
                    - b.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Sources", name: "NewSource"),
                    TargetSource(path: "OtherSource/b.swift", name: "c.swift"),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "a.swift"], names: ["NewSource", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["OtherSource", "b.swift"], names: ["OtherSource", "c.swift"], buildPhase: .sources)
            }

            $0.it("excludes sources") {
                let directories = """
                Sources:
                  - A:
                    - a.swift
                    - B:
                      - b.swift
                      - b.ignored
                    - a.ignored
                  - B:
                    - b.swift
                  - D:
                    - d.h
                    - d.m
                  - E:
                    - e.jpg
                    - e.h
                    - e.m
                    - F:
                      - f.swift
                  - G:
                    - H:
                      - h.swift
                  - types:
                    - a.swift
                    - a.m
                    - a.h
                    - a.x
                  - numbers:
                    - file1.a
                    - file2.a
                    - file3.a
                    - file4.a
                  - partial:
                    - file_part
                  - ignore.file
                  - a.ignored
                  - project.xcodeproj:
                    - project.pbxproj
                  - a.playground:
                    - Sources:
                      - a.swift
                    - Resources
                """
                try createDirectories(directories)

                let excludes = [
                    "B",
                    "d.m",
                    "E/F/*.swift",
                    "G/H/",
                    "types/*.[hx]",
                    "numbers/file[2-3].a",
                    "partial/*_part",
                    "ignore.file",
                    "*.ignored",
                    "*.xcodeproj",
                    "*.playground",
                    // not supported
                    // "**/*.ignored",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", excludes: excludes)])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "a.swift"])
                try pbxProj.expectFile(paths: ["Sources", "D", "d.h"])
                try pbxProj.expectFile(paths: ["Sources", "D", "d.m"])
                try pbxProj.expectFile(paths: ["Sources", "E", "e.jpg"])
                try pbxProj.expectFile(paths: ["Sources", "E", "e.m"])
                try pbxProj.expectFile(paths: ["Sources", "E", "e.h"])
                try pbxProj.expectFile(paths: ["Sources", "types", "a.swift"])
                try pbxProj.expectFile(paths: ["Sources", "numbers", "file1.a"])
                try pbxProj.expectFile(paths: ["Sources", "numbers", "file4.a"])
                try pbxProj.expectFileMissing(paths: ["Sources", "B", "b.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "E", "F", "f.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "G", "H", "h.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "types", "a.h"])
                try pbxProj.expectFileMissing(paths: ["Sources", "types", "a.x"])
                try pbxProj.expectFileMissing(paths: ["Sources", "numbers", "file2.a"])
                try pbxProj.expectFileMissing(paths: ["Sources", "numbers", "file3.a"])
                try pbxProj.expectFileMissing(paths: ["Sources", "partial", "file_part"])
                try pbxProj.expectFileMissing(paths: ["Sources", "a.ignored"])
                try pbxProj.expectFileMissing(paths: ["Sources", "ignore.file"])
                try pbxProj.expectFileMissing(paths: ["Sources", "project.xcodeproj"])
                try pbxProj.expectFileMissing(paths: ["Sources", "a.playground"])
                // not supported: "**/*.ignored"
                // try pbxProj.expectFileMissing(paths: ["Sources", "A", "a.ignored"])
                // try pbxProj.expectFileMissing(paths: ["Sources", "A", "B", "b.ignored"])
            }

            $0.it("generates file sources") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - Assets.xcassets
                    - B:
                      - b.swift
                      - c.jpg
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/a.swift",
                    "Sources/A/B/b.swift",
                    "Sources/A/Assets.xcassets",
                    "Sources/A/B/c.jpg",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/A/B", "b.swift"], names: ["B", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/A/B", "c.jpg"], names: ["B", "c.jpg"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["Sources/A", "Assets.xcassets"], names: ["A", "Assets.xcassets"], buildPhase: .resources)
            }

            $0.it("generates shared sources") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - B:
                      - b.swift
                      - c.jpg
                """
                try createDirectories(directories)

                let target1 = Target(name: "Test1", type: .framework, platform: .iOS, sources: ["Sources"])
                let target2 = Target(name: "Test2", type: .framework, platform: .tvOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target1, target2])

                _ = try project.generatePbxProj()
                // TODO: check there are build files for both targets
            }

            $0.it("generates intermediate groups") {

                let directories = """
                Sources:
                  A:
                    - b.swift
                  F:
                    - G:
                      - h.swift
                """
                try createDirectories(directories)
                let outOfSourceFile = outOfRootPath + "C/D/e.swift"
                try outOfSourceFile.parent().mkpath()
                try outOfSourceFile.write("")

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/b.swift",
                    "Sources/F/G/h.swift",
                    "../OtherDirectory/C/D/e.swift",
                ])
                let options = SpecOptions(createIntermediateGroups: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "F", "G", "h.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: [(outOfRootPath + "C/D").string, "e.swift"], names: ["D", "e.swift"], buildPhase: .sources)
            }

            $0.it("generates folder references") {
                let directories = """
                Sources:
                  A:
                    - a.resource
                    - b.resource
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Sources/A", type: .folder),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources/A"], names: ["A"], buildPhase: .resources)
                try pbxProj.expectFileMissing(paths: ["Sources", "A", "a.swift"])
            }

            $0.it("adds files to correct build phase") {
                let directories = """
                  A:
                    - file.swift
                    - file.xcassets
                    - file.h
                    - Info.plist
                    - file.xcconfig
                  B:
                    - file.swift
                    - file.xcassets
                    - file.h
                    - Info.plist
                    - file.xcconfig
                  C:
                    - file.swift
                    - file.m
                    - file.mm
                    - file.cpp
                    - file.c
                    - file.S
                    - file.h
                    - file.hh
                    - file.hpp
                    - file.ipp
                    - file.tpp
                    - file.hxx
                    - file.def
                    - file.xcconfig
                    - file.entitlements
                    - file.gpx
                    - file.apns
                    - file.123
                    - file.xcassets
                    - file.metal
                    - Info.plist
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .framework, platform: .iOS, sources: [
                    TargetSource(path: "A", buildPhase: .resources),
                    TargetSource(path: "B", buildPhase: .none),
                    TargetSource(path: "C", buildPhase: nil),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["A", "file.swift"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.xcassets"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.h"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "Info.plist"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["A", "file.xcconfig"], buildPhase: .resources)

                try pbxProj.expectFile(paths: ["B", "file.swift"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["B", "file.xcassets"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["B", "file.h"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["B", "Info.plist"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["B", "file.xcconfig"], buildPhase: .none)

                try pbxProj.expectFile(paths: ["C", "file.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.m"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.mm"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.cpp"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.c"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.S"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.h"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.hh"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.hpp"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.ipp"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.tpp"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.hxx"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.def"], buildPhase: .headers)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.entitlements"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.gpx"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.apns"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.xcassets"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "file.123"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "Info.plist"], buildPhase: .none)
                try pbxProj.expectFile(paths: ["C", "file.metal"], buildPhase: .sources)
            }

            $0.it("duplicate TargetSource is included once in sources build phase") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/a.swift",
                    "Sources/A/a.swift",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)

                let sourcesBuildPhase = pbxProj.buildPhases.first(where: { $0.buildPhase == BuildPhase.sources })!

                try expect(sourcesBuildPhase.files.count) == 1
            }

            $0.it("derived directories are sorted last") {
                let directories = """
                    A:
                    - file.swift
                    P:
                    - file.swift
                    S:
                    - file.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["A", "P", "S"], dependencies: [Dependency(type: .carthage, reference: "Alamofire")])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                let groups = try pbxProj.getMainGroup().children.map { $0.nameOrPath }
                try expect(groups) == ["A", "P", "S", "Frameworks", "Products"]
            }

            $0.it("sorts files") {
                let directories = """
                    Sources:
                    - file3.swift
                    - file.swift
                    - 10file.a
                    - 1file.a
                    - file2.swift
                    - group2:
                        - file.swift
                    - group:
                        - file.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"], dependencies: [Dependency(type: .carthage, reference: "Alamofire")])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                let mainGroup = try pbxProj.getMainGroup()
                let group = mainGroup.children.compactMap { $0 as? PBXGroup }.first { $0.nameOrPath == "Sources" }!
                let names = group.children.compactMap { $0.nameOrPath }
                try expect(names) == [
                    "1file.a",
                    "10file.a",
                    "file.swift",
                    "file2.swift",
                    "file3.swift",
                    "group",
                    "group2",
                ]
            }
        }
    }
}

extension PBXProj {

    /// expect a file within groups of the paths, using optional different names
    func expectFile(paths: [String], names: [String]? = nil, buildPhase: TargetSource.BuildPhase? = nil, file: String = #file, line: Int = #line) throws {
        guard let fileReference = getFileReference(paths: paths, names: names ?? paths) else {
            var error = "Could not find file at path \(paths.joined(separator: "/").quoted)"
            if let names = names, names != paths {
                error += " and name \(names.joined(separator: "/").quoted)"
            }
            throw failure(error, file: file, line: line)
        }

        if let buildPhase = buildPhase {
            let buildFile = buildFiles
                .first(where: { $0.file === fileReference })
            let actualBuildPhase = buildFile
                .flatMap { buildFile in buildPhases.first { $0.files.contains(buildFile) } }?.buildPhase

            var error: String?
            if let buildPhase = buildPhase.buildPhase {
                if actualBuildPhase != buildPhase {
                    if let actualBuildPhase = actualBuildPhase {
                        error = "is in the \(actualBuildPhase.rawValue) build phase instead of the expected \(buildPhase.rawValue.quoted)"
                    } else {
                        error = "isn't in a build phase when it's expected to be in \(buildPhase.rawValue.quoted)"
                    }
                }
            } else if let actualBuildPhase = actualBuildPhase {
                error = "is in the \(actualBuildPhase.rawValue.quoted) build phase when it's expected to not be in any"
            }
            if let error = error {
                throw failure("File \(paths.joined(separator: "/").quoted) \(error)", file: file, line: line)
            }
        }
    }

    /// expect a missing file within groups of the paths, using optional different names
    func expectFileMissing(paths: [String], names: [String]? = nil, file: String = #file, line: Int = #line) throws {
        let names = names ?? paths
        if getFileReference(paths: paths, names: names) != nil {
            throw failure("Found unexpected file at path \(paths.joined(separator: "/").quoted) and name \(paths.joined(separator: "/").quoted)", file: file, line: line)
        }
    }

    func getFileReference(paths: [String], names: [String], file: String = #file, line: Int = #line) -> PBXFileReference? {
        guard let mainGroup = projects.first?.mainGroup else { return nil }

        return getFileReference(group: mainGroup, paths: paths, names: names)
    }

    func getMainGroup(function: String = #function, file: String = #file, line: Int = #line) throws -> PBXGroup {
        guard let mainGroup = projects.first?.mainGroup else {
            throw failure("Couldn't find main group", file: file, line: line)
        }
        return mainGroup
    }

    private func getFileReference(group: PBXGroup, paths: [String], names: [String]) -> PBXFileReference? {

        guard !paths.isEmpty else { return nil }
        let path = paths.first!
        let name = names.first!
        let restOfPath = Array(paths.dropFirst())
        let restOfName = Array(names.dropFirst())
        if restOfPath.isEmpty {
            let fileReferences: [PBXFileReference] = group.children.compactMap { $0 as? PBXFileReference }
            return fileReferences.first { $0.path == path && $0.nameOrPath == name }
        } else {
            let groups = group.children.compactMap { $0 as? PBXGroup }
            guard let group = groups.first(where: { $0.path == path && $0.nameOrPath == name }) else { return nil }
            return getFileReference(group: group, paths: restOfPath, names: restOfName)
        }
    }
}
