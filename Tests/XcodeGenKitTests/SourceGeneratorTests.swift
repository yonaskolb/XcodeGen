import PathKit
import ProjectSpec
import Spectre
@testable import XcodeGenKit
import XcodeProj
import XCTest
import Yams
import TestSupport

class SourceGeneratorTests: XCTestCase {

    func testSourceGenerator() throws {
        try skipIfNecessary()
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
            
            func createFile(at relativePath: Path, content: String) throws -> Path {
                let filePath = directoryPath + relativePath
                try filePath.parent().mkpath()
                try filePath.write(content)
                return filePath
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
                    - C2.0:
                      - c.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "A", "B", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "A", "C2.0", "c.swift"], buildPhase: .sources)
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
                let buildFile = try unwrap(pbxProj.buildFiles
                    .first(where: { $0.file == fileReference }))
                try expect(buildPhase?.files?.count) == 1
                try expect(buildPhase?.files?.contains(buildFile)) == true
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
                let fileReference = try unwrap(pbxProj.fileReferences.first(where: { $0.nameOrPath == "model2.xcdatamodel" }))
                let versionGroup = try unwrap(pbxProj.versionGroups.first)
                try expect(versionGroup.currentVersion) == fileReference
                try expect(versionGroup.children.count) == 3
                try expect(versionGroup.path) == "model.xcdatamodeld"
                try expect(fileReference.path) == "model2.xcdatamodel"
            }

            $0.it("generates core data mapping models") {
                let directories = """
                Sources:
                    model.xcmappingmodel:
                        - xcmapping.xml
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["Sources"])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "model.xcmappingmodel"], buildPhase: .sources)
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
                    pbxProj.fileReferences.filter { $0.path == path }
                }

                func getVariableGroups(_ name: String?) -> [PBXVariantGroup] {
                    pbxProj.variantGroups.filter { $0.name == name }
                }

                let resourceName = "LocalizedStoryboard.storyboard"
                let baseResource = "Base.lproj/LocalizedStoryboard.storyboard"
                let localizedResource = "en.lproj/LocalizedStoryboard.strings"

                let variableGroup = try unwrap(getVariableGroups(resourceName).first)

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

            $0.it("handles localized resources") {
                let directories = """
                App:
                    Resources:
                        en-CA.lproj:
                            - empty.json
                            - Localizable.strings
                        en-US.lproj:
                            - empty.json
                            - Localizable.strings
                        en.lproj:
                            - empty.json
                            - Localizable.strings
                        fonts:
                            SFUI:
                                - SFUILight.ttf
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "App/Resources")])

                let options = SpecOptions(createIntermediateGroups: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let outputXcodeProj = try project.generateXcodeProject()
                try outputXcodeProj.write(path: directoryPath)

                let inputXcodeProj = try XcodeProj(path: directoryPath)
                let pbxProj = inputXcodeProj.pbxproj

                func getFileReferences(_ path: String) -> [PBXFileReference] {
                    pbxProj.fileReferences.filter { $0.path == path }
                }

                func getVariableGroups(_ name: String?) -> [PBXVariantGroup] {
                    pbxProj.variantGroups.filter { $0.name == name }
                }

                let stringsResourceName = "Localizable.strings"
                let jsonResourceName = "empty.json"

                let stringsVariableGroup = try unwrap(getVariableGroups(stringsResourceName).first)

                let jsonVariableGroup = try unwrap(getVariableGroups(jsonResourceName).first)

                let stringsResource = "en.lproj/Localizable.strings"
                let jsonResource = "en-CA.lproj/empty.json"

                do {
                    let refs = getFileReferences(stringsResource)
                    try expect(refs.count) == 1
                    try expect(refs.first!.uuid.hasPrefix("TEMP")) == false
                    try expect(stringsVariableGroup.children.filter { $0 == refs.first }.count) == 1
                }

                do {
                    let refs = getFileReferences(jsonResource)
                    try expect(refs.count) == 1
                    try expect(refs.first!.uuid.hasPrefix("TEMP")) == false
                    try expect(jsonVariableGroup.children.filter { $0 == refs.first }.count) == 1
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
                      - b.alsoIgnored
                    - a.ignored
                    - a.alsoIgnored
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
                    "**/*.ignored",
                    "A/B/**/*.alsoIgnored",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", excludes: excludes)])

                func test(generateEmptyDirectories: Bool) throws {
                    let options = SpecOptions(generateEmptyDirectories: generateEmptyDirectories)
                    let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)
                    let pbxProj = try project.generatePbxProj()
                    try pbxProj.expectFile(paths: ["Sources", "A", "a.swift"])
                    try pbxProj.expectFile(paths: ["Sources", "A", "a.alsoIgnored"])
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
                    try pbxProj.expectFileMissing(paths: ["Sources", "A", "a.ignored"])
                    try pbxProj.expectFileMissing(paths: ["Sources", "A", "B", "b.ignored"])
                    try pbxProj.expectFileMissing(paths: ["Sources", "A", "B", "b.alsoIgnored"])
                }

                try test(generateEmptyDirectories: false)
                try test(generateEmptyDirectories: true)
            }

            $0.it("excludes certain ignored files") {
                let directories = """
                Sources:
                  A:
                    - a.swift
                    - .DS_Store
                    - a.swift.orig
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources")])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "a.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "A", ".DS_Store"])
                try pbxProj.expectFileMissing(paths: ["Sources", "A", "a.swift.orig"])
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
                    - D2.0:
                      - d.swift
                    - E.bundle:
                      - e.json
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/a.swift",
                    "Sources/A/B/b.swift",
                    "Sources/A/D2.0/d.swift",
                    "Sources/A/Assets.xcassets",
                    "Sources/A/E.bundle/e.json",
                    "Sources/A/B/c.jpg",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources/A", "a.swift"], names: ["A", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/A/B", "b.swift"], names: ["B", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/A/D2.0", "d.swift"], names: ["D2.0", "d.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/A/B", "c.jpg"], names: ["B", "c.jpg"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["Sources/A", "Assets.xcassets"], names: ["A", "Assets.xcassets"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["Sources/A/E.bundle", "e.json"], names: ["E.bundle", "e.json"], buildPhase: .resources)
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
                  B:
                    - b.swift
                """
                try createDirectories(directories)
                let outOfSourceFile = outOfRootPath + "C/D/e.swift"
                try outOfSourceFile.parent().mkpath()
                try outOfSourceFile.write("")

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources/A/b.swift",
                    "Sources/F/G/h.swift",
                    "../OtherDirectory/C/D/e.swift",
                    TargetSource(path: "Sources/B", createIntermediateGroups: false),
                ])
                let options = SpecOptions(createIntermediateGroups: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "A", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "F", "G", "h.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["..", "OtherDirectory", "C", "D", "e.swift"], names: [".", "OtherDirectory", "C", "D", "e.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources/B", "b.swift"], names: ["B", "b.swift"], buildPhase: .sources)
            }

            $0.it("generates custom groups") {

                let directories = """
                - Sources:
                  - a.swift
                  - A:
                    - b.swift
                  - F:
                    - G:
                      - h.swift
                      - i.swift
                  - B:
                    - b.swift
                    - C:
                      - c.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Sources/a.swift", group: "CustomGroup1"),
                    TargetSource(path: "Sources/A/b.swift", group: "CustomGroup1"),
                    TargetSource(path: "Sources/F/G/h.swift", group: "CustomGroup1"),
                    TargetSource(path: "Sources/B", group: "CustomGroup2", createIntermediateGroups: false),
                    TargetSource(path: "Sources/F/G/i.swift", group: "Sources/F/G/CustomGroup3"),
                ])

                let options = SpecOptions(createIntermediateGroups: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["CustomGroup1", "Sources/a.swift"], names: ["CustomGroup1", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["CustomGroup1", "Sources/A/b.swift"], names: ["CustomGroup1", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["CustomGroup1", "Sources/F/G/h.swift"], names: ["CustomGroup1", "h.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "F", "G", "CustomGroup3", "i.swift"], names: ["Sources", "F", "G", "CustomGroup3", "i.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["CustomGroup2", "Sources/B", "b.swift"], names: ["CustomGroup2", "B", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["CustomGroup2", "Sources/B", "C", "c.swift"], names: ["CustomGroup2", "B", "C", "c.swift"], buildPhase: .sources)
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
                    - GoogleService-Info.plist
                    - file.xcconfig
                    - Localizable.xcstrings
                  B:
                    - file.swift
                    - file.xcassets
                    - file.h
                    - Sample.plist
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
                    - file.mlmodel
                    - file.mlpackage
                    - file.mlmodelc
                    - Info.plist
                    - Intent.intentdefinition
                    - Configuration.storekit
                    - Settings.bundle:
                      - en.lproj:
                        - Root.strings
                      - Root.plist
                    - WithPeriod2.0:
                      - file.swift
                    - Documentation.docc
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .framework, platform: .iOS, sources: [
                    TargetSource(path: "A", buildPhase: .resources),
                    TargetSource(path: "B", buildPhase: BuildPhaseSpec.none),
                    TargetSource(path: "C", buildPhase: nil),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["A", "file.swift"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.xcassets"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.h"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "GoogleService-Info.plist"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.xcconfig"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "Localizable.xcstrings"], buildPhase: .resources)

                try pbxProj.expectFile(paths: ["B", "file.swift"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["B", "file.xcassets"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["B", "file.h"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["B", "Sample.plist"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["B", "file.xcconfig"], buildPhase: BuildPhaseSpec.none)

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
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.entitlements"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.gpx"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.apns"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.xcconfig"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.xcassets"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "file.123"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "Info.plist"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["C", "file.metal"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.mlmodel"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.mlpackage"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "file.mlmodelc"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "Intent.intentdefinition"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "Configuration.storekit"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "Settings.bundle"], buildPhase: .resources)
                try pbxProj.expectFileMissing(paths: ["C", "Settings.bundle", "en.lproj"])
                try pbxProj.expectFileMissing(paths: ["C", "Settings.bundle", "en.lproj", "Root.strings"])
                try pbxProj.expectFileMissing(paths: ["C", "Settings.bundle", "Root.plist"])
                try pbxProj.expectFileMissing(paths: ["C", "WithPeriod2.0"])
                try pbxProj.expectFile(paths: ["C", "WithPeriod2.0", "file.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["C", "Documentation.docc"], buildPhase: .sources)
            }

            $0.it("only omits the defined Info.plist from resource build phases but not other plists") {
                try createDirectories("""
                  A:
                    - A-Info.plist
                  B:
                    - Info.plist
                    - GoogleServices-Info.plist
                  C:
                    - Info.plist
                    - Info-Production.plist
                  D:
                    - Info-Staging.plist
                    - Info-Production.plist
                """)

                // Explicit plist.path value is respected
                let targetA = Target(
                    name: "A",
                    type: .application,
                    platform: .iOS,
                    sources: ["A"],
                    info: Plist(path: "A/A-Info.plist")
                )

                // Automatically picks first 'Info.plist' at the top-level
                let targetB = Target(
                    name: "B",
                    type: .application,
                    platform: .iOS,
                    sources: ["B"]
                )

                // Also respects INFOPLIST_FILE, ignores other files named Info.plist
                let targetC = Target(
                    name: "C",
                    type: .application,
                    platform: .iOS,
                    settings: Settings(dictionary: [
                        "INFOPLIST_FILE": "C/Info-Production.plist"
                    ]),
                    sources: ["C"]
                )

                // Does not support INFOPLIST_FILE value that requires expanding
                let targetD = Target(
                    name: "D",
                    type: .application,
                    platform: .iOS,
                    settings: Settings(dictionary: [
                        "ENVIRONMENT": "Production",
                        "INFOPLIST_FILE": "D/Info-${ENVIRONMENT}.plist"
                    ]),
                    sources: ["D"]
                )

                let project = Project(basePath: directoryPath.absolute(), name: "Test", targets: [targetA, targetB, targetC, targetD])
                let pbxProj = try project.generatePbxProj()

                try pbxProj.expectFile(paths: ["A", "A-Info.plist"], buildPhase: BuildPhaseSpec.none)

                try pbxProj.expectFile(paths: ["B", "Info.plist"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["B", "GoogleServices-Info.plist"], buildPhase: .resources)

                try pbxProj.expectFile(paths: ["C", "Info.plist"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["C", "Info-Production.plist"], buildPhase: BuildPhaseSpec.none)

                try pbxProj.expectFile(paths: ["D", "Info-Staging.plist"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["D", "Info-Production.plist"], buildPhase: .resources)
            }

            $0.it("sets file type properties") {
                let directories = """
                  A:
                    - file.resource1
                    - file.source1
                    - file.abc:
                        - file.a
                    - file.exclude1
                    - file.unphased1
                    - ignored.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .framework, platform: .iOS, sources: [
                    TargetSource(path: "A"),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: .init(fileTypes: [
                    "abc": FileType(buildPhase: .sources),
                    "source1": FileType(buildPhase: .sources, attributes: ["a1", "a2"], resourceTags: ["r1", "r2"], compilerFlags: ["-c1", "-c2"]),
                    "resource1": FileType(buildPhase: .resources, attributes: ["a1", "a2"], resourceTags: ["r1", "r2"], compilerFlags: ["-c1", "-c2"]),
                    "unphased1": FileType(buildPhase: BuildPhaseSpec.none),
                    "swift": FileType(buildPhase: .resources),
                ]))

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["A", "file.abc"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["A", "file.source1"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["A", "file.resource1"], buildPhase: .resources)
                try pbxProj.expectFile(paths: ["A", "file.unphased1"], buildPhase: BuildPhaseSpec.none)
                try pbxProj.expectFile(paths: ["A", "ignored.swift"], buildPhase: .resources)

                do {
                    let fileReference = try unwrap(pbxProj.getFileReference(paths: ["A", "file.resource1"], names: ["A", "file.resource1"]))
                    let buildFile = try unwrap(pbxProj.buildFiles.first(where: { $0.file === fileReference }))
                    let settings = NSDictionary(dictionary: buildFile.settings ?? [:])
                    try expect(settings) == [
                        "ATTRIBUTES": ["a1", "a2"],
                        "ASSET_TAGS": ["r1", "r2"],
                    ]
                }
                do {
                    let fileReference = try unwrap(pbxProj.getFileReference(paths: ["A", "file.source1"], names: ["A", "file.source1"]))
                    let buildFile = try unwrap(pbxProj.buildFiles.first(where: { $0.file === fileReference }))
                    let settings = NSDictionary(dictionary: buildFile.settings ?? [:])
                    try expect(settings) == [
                        "ATTRIBUTES": ["a1", "a2"],
                        "COMPILER_FLAGS": "-c1 -c2",
                        ]
                }
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

                try expect(sourcesBuildPhase.files?.count) == 1
            }

            $0.it("add only carthage dependencies with same platform") {
                let directories = """
                    A:
                    - file.swift
                """
                try createDirectories(directories)

                let watchTarget = Target(name: "Watch", type: .watch2App, platform: .watchOS, sources: ["A"], dependencies: [Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire_watch")])
                let watchDependency = Dependency(type: .target, reference: "Watch")
                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["A"], dependencies: [Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire"), watchDependency])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target, watchTarget])

                let pbxProj = try project.generatePbxProj()
                let carthagePhase = pbxProj.nativeTargets.first(where: { $0.name == "Test" })?.buildPhases.first(where: { $0 is PBXShellScriptBuildPhase }) as? PBXShellScriptBuildPhase
                try expect(carthagePhase?.inputPaths) == ["$(SRCROOT)/Carthage/Build/iOS/Alamofire.framework"]
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

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: ["A", "P", "S"], dependencies: [Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire")])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                let groups = try pbxProj.getMainGroup().children.map { $0.nameOrPath }
                try expect(groups) == ["A", "P", "S", "Frameworks", "Products"]
            }

            $0.it("sorts files") {
                let directories = """
                    A:
                    - A.swift
                    Source:
                        - file.swift
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
                    Z:
                    - A:
                        - file.swift
                    B:
                    - file.swift
                """
                try createDirectories(directories)

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources",
                    TargetSource(path: "Source", name: "S"),
                    "A",
                    TargetSource(path: "Z/A", name: "B"),
                    "B",
                ], dependencies: [Dependency(type: .carthage(findFrameworks: false, linkType: .dynamic), reference: "Alamofire")])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                let mainGroup = try pbxProj.getMainGroup()
                let mainGroupNames = mainGroup.children.prefix(5).map { $0.name }
                try expect(mainGroupNames) == [
                    nil,
                    nil,
                    "B",
                    "S",
                    nil,
                ]
                let mainGroupPaths = mainGroup.children.prefix(5).map { $0.path }
                try expect(mainGroupPaths) == [
                    "A",
                    "B",
                    "Z/A",
                    "Source",
                    "Sources",
                ]

                let group = mainGroup.children.compactMap { $0 as? PBXGroup }.first { $0.path == "Sources" }!
                let names = group.children.map { $0.name }
                try expect(names) == [
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                ]
                let paths = group.children.map { $0.path }
                try expect(paths) == [
                    "1file.a",
                    "10file.a",
                    "file.swift",
                    "file2.swift",
                    "file3.swift",
                    "group",
                    "group2",
                ]
            }

            $0.it("adds missing optional files and folders") {

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "File1.swift", optional: true),
                    TargetSource(path: "File2.swift", type: .file, optional: true),
                    TargetSource(path: "Group", type: .folder, optional: true),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["File1.swift"])
                try pbxProj.expectFile(paths: ["File2.swift"])
            }

            $0.it("allows missing optional groups") {

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    TargetSource(path: "Group1", optional: true),
                    TargetSource(path: "Group2", type: .group, optional: true),
                    TargetSource(path: "Group3", type: .group, optional: true),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                _ = try project.generatePbxProj()
            }

            $0.it("relative path items outside base path are grouped together") {
                let directories = """
                Sources:
                  - Inside:
                    - a.swift
                    - Inside2:
                        - b.swift
                """
                try createDirectories(directories)

                let outOfSourceFile1 = outOfRootPath + "Outside/a.swift"
                try outOfSourceFile1.parent().mkpath()
                try outOfSourceFile1.write("")

                let outOfSourceFile2 = outOfRootPath + "Outside/Outside2/b.swift"
                try outOfSourceFile2.parent().mkpath()
                try outOfSourceFile2.write("")

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [
                    "Sources",
                    "../OtherDirectory",
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()
                try pbxProj.expectFile(paths: ["Sources", "Inside", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["Sources", "Inside", "Inside2", "b.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["../OtherDirectory", "Outside", "a.swift"], names: ["OtherDirectory", "Outside", "a.swift"], buildPhase: .sources)
                try pbxProj.expectFile(paths: ["../OtherDirectory", "Outside", "Outside2", "b.swift"], names: ["OtherDirectory", "Outside", "Outside2", "b.swift"], buildPhase: .sources)
            }

            $0.it("correctly adds target source attributes") {
                let directories = """
                A:
                  - Intent.intentdefinition
                """
                try createDirectories(directories)

                let definition: String = "Intent.intentdefinition"

                let target = Target(name: "Test", type: .framework, platform: .iOS, sources: [
                    TargetSource(path: "A/\(definition)", buildPhase: .sources, attributes: ["no_codegen"]),
                ])
                let project = Project(basePath: directoryPath, name: "Test", targets: [target])

                let pbxProj = try project.generatePbxProj()

                let fileReference = pbxProj.getFileReference(
                    paths: ["A", definition],
                    names: ["A", definition]
                )
                let buildFile = try unwrap(pbxProj.buildFiles.first(where: { $0.file == fileReference }))

                try pbxProj.expectFile(paths: ["A", definition], buildPhase: .sources)

                if (buildFile.settings! as NSDictionary) != (["ATTRIBUTES": ["no_codegen"]] as NSDictionary) {
                    throw failure("File does not contain no_codegen attribute")
                }
            }

            $0.it("includes only the specified files when includes is present") {
                let directories = """
                Sources:
                  - file3.swift
                  - file3Tests.swift
                  - file2.swift
                  - file2Tests.swift
                  - group2:
                    - file.swift
                    - fileTests.swift
                  - group:
                    - file.swift
                  - group3:
                    - group4:
                      - group5:
                        - file.swift
                        - file5Tests.swift
                        - file6Tests.m
                        - file6Tests.h
                """
                try createDirectories(directories)

                let includes = [
                    "**/*Tests.*",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", includes: includes)])

                let options = SpecOptions(createIntermediateGroups: true, generateEmptyDirectories: true)
                let project = Project(basePath: directoryPath, name: "Test", targets: [target], options: options)
                let pbxProj = try project.generatePbxProj()

                try pbxProj.expectFile(paths: ["Sources", "file2Tests.swift"])
                try pbxProj.expectFile(paths: ["Sources", "file3Tests.swift"])
                try pbxProj.expectFile(paths: ["Sources", "group2", "fileTests.swift"])
                try pbxProj.expectFile(paths: ["Sources", "group3", "group4", "group5", "file5Tests.swift"])
                try pbxProj.expectFile(paths: ["Sources", "group3", "group4", "group5", "file6Tests.h"])
                try pbxProj.expectFile(paths: ["Sources", "group3", "group4", "group5", "file6Tests.m"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file2.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file3.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group2", "file.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group", "file.swift"])
            }

            $0.it("handles includes with no matches correctly") {
                let directories = """
                Sources:
                  - file3.swift
                  - file3Tests.swift
                  - file2.swift
                  - file2Tests.swift
                  - group2:
                    - file.swift
                    - fileTests.swift
                  - group:
                    - file.swift
                """
                try createDirectories(directories)

                let includes = [
                    "**/*NonExistent.*",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", includes: includes)])

                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                let pbxProj = try project.generatePbxProj()

                try pbxProj.expectFileMissing(paths: ["Sources", "file2.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file3.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file2Tests.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file3Tests.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group2", "file.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group2", "fileTests.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group", "file.swift"])
            }

            $0.it("prioritizes excludes over includes when both are present") {
                let directories = """
                Sources:
                  - file3.swift
                  - file3Tests.swift
                  - file2.swift
                  - file2Tests.swift
                  - group2:
                    - file.swift
                    - fileTests.swift
                  - group:
                    - file.swift
                """
                try createDirectories(directories)

                let includes = [
                    "**/*Tests.*",
                ]

                let excludes = [
                    "group2",
                ]

                let target = Target(name: "Test", type: .application, platform: .iOS, sources: [TargetSource(path: "Sources", excludes: excludes, includes: includes)])

                let project = Project(basePath: directoryPath, name: "Test", targets: [target])
                let pbxProj = try project.generatePbxProj()

                try pbxProj.expectFile(paths: ["Sources", "file2Tests.swift"])
                try pbxProj.expectFile(paths: ["Sources", "file3Tests.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group2", "fileTests.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file2.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "file3.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group2", "file.swift"])
                try pbxProj.expectFileMissing(paths: ["Sources", "group", "file.swift"])
            }

            $0.describe("Localized sources") {
                $0.context("With localized sources") {
                    $0.it("*.intentdefinition should be added to source phase") {
                        let directories = """
                        Sources:
                            Base.lproj:
                                - Intents.intentdefinition
                            en.lproj:
                                - Intents.strings
                            ja.lproj:
                                - Intents.strings
                        """
                        try createDirectories(directories)
                        let directoryPath = Path("TestDirectory")

                        let target = Target(name: "IntentDefinitions",
                                            type: .application,
                                            platform: .iOS,
                                            sources: [TargetSource(path: "Sources")])
                        let project = Project(basePath: directoryPath,
                                              name: "IntendDefinitions",
                                              targets: [target])
                        let pbxProj = try project.generatePbxProj()
                        let sourceBuildPhase = try unwrap(pbxProj.buildPhases.first { $0.buildPhase == .sources })
                        try expect(sourceBuildPhase.files?.compactMap { $0.file?.nameOrPath }) == ["Intents.intentdefinition"]
                    }
                }

                $0.context("With localized sources with buildPhase") {
                    $0.it("*.intentdefinition with buildPhase should be added to resource phase") {
                        let directories = """
                        Sources:
                            Base.lproj:
                                - Intents.intentdefinition
                            en.lproj:
                                - Intents.strings
                            ja.lproj:
                                - Intents.strings
                        """
                        try createDirectories(directories)
                        let directoryPath = Path("TestDirectory")

                        let target = Target(name: "IntentDefinitions",
                                            type: .application,
                                            platform: .iOS,
                                            sources: [TargetSource(path: "Sources", buildPhase: .resources)])
                        let project = Project(basePath: directoryPath,
                                              name: "IntendDefinitions",
                                              targets: [target])
                        let pbxProj = try project.generatePbxProj()
                        let sourceBuildPhase = try unwrap(pbxProj.buildPhases.first { $0.buildPhase == .sources })
                        let resourcesBuildPhase = try unwrap(pbxProj.buildPhases.first { $0.buildPhase == .resources })
                        try expect(sourceBuildPhase.files) == []
                        try expect(resourcesBuildPhase.files?.compactMap { $0.file?.nameOrPath }) == ["Intents.intentdefinition"]
                    }
                }

                $0.it("generates resource tags") {
                    let directories = """
                    A:
                        - resourceFile.mp4
                        - resourceFile2.mp4
                        - sourceFile.swift
                    """
                    try createDirectories(directories)

                    let target = Target(
                        name: "Test",
                        type: .application,
                        platform: .iOS,
                        sources: [
                            TargetSource(path: "A/resourceFile.mp4", buildPhase: .resources, resourceTags: ["tag1", "tag2"]),
                            TargetSource(path: "A/resourceFile2.mp4", buildPhase: .resources, resourceTags: ["tag2", "tag3"]),
                            TargetSource(path: "A/sourceFile.swift", buildPhase: .sources, resourceTags: ["tag1", "tag2"]),
                        ]
                    )

                    let project = Project(basePath: directoryPath,
                                          name: "Test",
                                          targets: [target])

                    let pbxProj = try project.generatePbxProj()

                    let resourceFileReference = try unwrap(pbxProj.getFileReference(
                        paths: ["A", "resourceFile.mp4"],
                        names: ["A", "resourceFile.mp4"]
                    ))

                    let resourceFileReference2 = try unwrap(pbxProj.getFileReference(
                        paths: ["A", "resourceFile2.mp4"],
                        names: ["A", "resourceFile2.mp4"]
                    ))

                    let sourceFileReference = try unwrap(pbxProj.getFileReference(
                        paths: ["A", "sourceFile.swift"],
                        names: ["A", "sourceFile.swift"]
                    ))

                    try pbxProj.expectFile(paths: ["A", "resourceFile.mp4"], buildPhase: .resources)
                    try pbxProj.expectFile(paths: ["A", "resourceFile2.mp4"], buildPhase: .resources)
                    try pbxProj.expectFile(paths: ["A", "sourceFile.swift"], buildPhase: .sources)

                    let resourceBuildFile = try unwrap(pbxProj.buildFiles.first(where: { $0.file == resourceFileReference }))
                    let resourceBuildFile2 = try unwrap(pbxProj.buildFiles.first(where: { $0.file == resourceFileReference2 }))
                    let sourceBuildFile = try unwrap(pbxProj.buildFiles.first(where: { $0.file == sourceFileReference }))

                    if (resourceBuildFile.settings! as NSDictionary) != (["ASSET_TAGS": ["tag1", "tag2"]] as NSDictionary) {
                        throw failure("File does not contain tag1 and tag2 ASSET_TAGS")
                    }

                    if (resourceBuildFile2.settings! as NSDictionary) != (["ASSET_TAGS": ["tag2", "tag3"]] as NSDictionary) {
                        throw failure("File does not contain tag2 and tag3 ASSET_TAGS")
                    }

                    if sourceBuildFile.settings != nil {
                        throw failure("File that buildPhase is source contain settings")
                    }

                    if !pbxProj.rootObject!.attributes.keys.contains("knownAssetTags") {
                        throw failure("PBXProject does not contain knownAssetTags")
                    }

                    try expect(pbxProj.rootObject!.attributes["knownAssetTags"] as? [String]) == ["tag1", "tag2", "tag3"]
                }
                
                $0.it("Detects all locales present in a String Catalog") {
                    /// This is a catalog with gaps:
                    /// - String "foo" is translated into English (en) and Spanish (es)
                    /// - String "bar" is translated into English (en) and Italian (it)
                    ///
                    /// It is aimed at representing real world scenarios where translators have not finished translating all strings into their respective languages.
                    /// The expectation in this kind of cases is that `includedLocales` returns all locales found at least once in the catalog.
                    /// In this example, `includedLocales` is expected to be a set only containing "en", "es" and "it".
                    let stringCatalogContent = """
                    {
                      "sourceLanguage" : "en",
                      "strings" : {
                        "foo" : {
                          "comment" : "Sample string in an asset catalog",
                          "extractionState" : "manual",
                          "localizations" : {
                            "en" : {
                              "stringUnit" : {
                                "state" : "translated",
                                "value" : "Foo English"
                              }
                            },
                            "es" : {
                              "stringUnit" : {
                                "state" : "translated",
                                "value" : "Foo Spanish"
                              }
                            }
                          }
                        },
                        "bar" : {
                          "comment" : "Another sample string in an asset catalog",
                          "extractionState" : "manual",
                          "localizations" : {
                            "en" : {
                              "stringUnit" : {
                                "state" : "translated",
                                "value" : "Bar English"
                              }
                            },
                            "it" : {
                              "stringUnit" : {
                                "state" : "translated",
                                "value" : "Bar Italian"
                              }
                            }
                          }
                        }
                      },
                      "version" : "1.0"
                    }
                    """
                    
                    let testStringCatalogRelativePath = Path("Localizable.xcstrings")
                    let testStringCatalogPath = try createFile(at: testStringCatalogRelativePath, content: stringCatalogContent)

                    guard let stringCatalog = StringCatalog(from: testStringCatalogPath) else {
                        throw failure("Failed decoding string catalog from \(testStringCatalogPath)")
                    }
                    
                    try expect(stringCatalog.includedLocales.sorted(by: { $0 < $1 })) == ["en", "es", "it"]
                }
            }
        }
    }
}

extension PBXProj {

    /// expect a file within groups of the paths, using optional different names
    func expectFile(paths: [String], names: [String]? = nil, buildPhase: BuildPhaseSpec? = nil, file: String = #file, line: Int = #line) throws {
        guard let fileReference = getFileReference(paths: paths, names: names ?? paths) else {
            var error = "Could not find file at path \(paths.joined(separator: "/").quoted)"
            if let names = names, names != paths {
                error += " and name \(names.joined(separator: "/").quoted)"
            }
            error += "\n\(self.printGroups())"
            throw failure(error, file: file, line: line)
        }

        if let buildPhase = buildPhase {
            let buildFile = buildFiles
                .first(where: { $0.file === fileReference })
            let actualBuildPhase = buildFile
                .flatMap { buildFile in buildPhases.first { $0.files?.contains(buildFile) ?? false } }?.buildPhase

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

    private func getFileReference(group: PBXGroup, paths: [String], names: [String]) -> PBXFileReference? {
        guard !paths.isEmpty else {
            return nil
        }

        let path = paths.first!
        let name = names.first!
        let restOfPath = Array(paths.dropFirst())
        let restOfName = Array(names.dropFirst())
        if restOfPath.isEmpty {
            let fileReferences: [PBXFileReference] = group.children.compactMap { $0 as? PBXFileReference }
            return fileReferences.first { ($0.path == nil || $0.path == path) && $0.nameOrPath == name }
        } else {
            let groups = group.children.compactMap { $0 as? PBXGroup }
            guard let group = groups.first(where: { ($0.path == nil || $0.path == path) && $0.nameOrPath == name }) else {
                return nil
            }
            return getFileReference(group: group, paths: restOfPath, names: restOfName)
        }
    }
}
