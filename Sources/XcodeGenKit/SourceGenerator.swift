//
//  SourceGenerator.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 11/11/17.
//

import Foundation
import ProjectSpec
import PathKit
import xcproj

struct SourceFile {
    let path: Path
    let fileReference: String
    let buildFile: PBXBuildFile
    let buildPhase: BuildPhase?
}

class SourceGenerator {

    var rootGroups: Set<String> = []
    private var fileReferencesByPath: [Path: String] = [:]
    private var groupsByPath: [Path: PBXGroup] = [:]
    private var variantGroupsByPath: [Path: PBXVariantGroup] = [:]

    private let spec: ProjectSpec
    private let referenceGenerator: ReferenceGenerator
    private let proj: PBXProj
    var addObject: (PBXObject) -> Void

    init(spec: ProjectSpec, proj: PBXProj, referenceGenerator: ReferenceGenerator, addObject: @escaping (PBXObject) -> Void) {
        self.spec = spec
        self.proj = proj
        self.referenceGenerator = referenceGenerator
        self.addObject = addObject
    }

    func getAllSourceFiles(sources: [TargetSource]) throws -> [SourceFile] {
        return try sources.flatMap { try getSourceFiles(targetSource: $0, path: spec.basePath + $0.path) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        // TODO: call a seperate function that only creates groups not source files
        _ = try getGroupSources(targetSource: TargetSource(path: path), path: spec.basePath + path, isBaseGroup: true)
    }

    func generateSourceFile(targetSource: TargetSource, path: Path, buildPhase: BuildPhase? = nil) -> SourceFile {
        let fileReference = fileReferencesByPath[path]!
        var settings: [String: Any] = [:]
        let buildPhase = buildPhase ?? getDefaultBuildPhase(for: path)

        if buildPhase == .headers {
            settings = ["ATTRIBUTES": ["Public"]]
        }
        if targetSource.compilerFlags.count > 0 {
            settings["COMPILER_FLAGS"] = targetSource.compilerFlags.joined(separator: " ")
        }

        //TODO: add the target name to the reference generator string so shared files don't have same reference (that will be escaped by appending a number)
        let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference), fileRef: fileReference, settings: settings.isEmpty ? nil : settings)
        return SourceFile(path: path, fileReference: fileReference, buildFile: buildFile, buildPhase: buildPhase)
    }

    func getFileReference(path: Path, inPath: Path, name: String? = nil, sourceTree: PBXSourceTree = .group) -> String {
        if let fileReference = fileReferencesByPath[path] {
            return fileReference
        } else {
            let fileReference = PBXFileReference(reference: referenceGenerator.generate(PBXFileReference.self, path.lastComponent), sourceTree: sourceTree, name: name, path: path.byRemovingBase(path: inPath).string)
            addObject(fileReference)
            fileReferencesByPath[path] = fileReference.reference
            return fileReference.reference
        }
    }


    private func getDefaultBuildPhase(for path: Path) -> BuildPhase? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "swift", "m", "mm", "cpp", "c", "S": return .sources
            case "h", "hh", "hpp", "ipp", "tpp", "hxx", "def": return .headers
            case "xcconfig", "entitlements", "gpx", "lproj", "apns": return nil
            default: return .resources
            }
        }
        return nil
    }

    private func getGroup(path: Path, name: String? = nil, mergingChildren children: [String], createIntermediateGroups: Bool, isBaseGroup: Bool) -> PBXGroup {
        let group: PBXGroup
        
        if let cachedGroup = groupsByPath[path] {
            // only add the children that aren't already in the cachedGroup
            cachedGroup.children = Array(Set(cachedGroup.children + children))
            group = cachedGroup
        } else {

            // lives outside the spec base path
            let isOutOfBasePath = !path.string.contains(spec.basePath.string)

            // has no valid parent paths
            let isRootPath = isOutOfBasePath || path.parent() == spec.basePath

            // is a top level group in the project
            let isTopLevelGroup = (isBaseGroup && !createIntermediateGroups) || isRootPath

            group = PBXGroup(
                reference: referenceGenerator.generate(PBXGroup.self, path.lastComponent),
                children: children,
                sourceTree: .group,
                name: name ?? path.lastComponent,
                path: isTopLevelGroup ?
                    path.byRemovingBase(path: spec.basePath).string :
                    path.lastComponent
            )
            addObject(group)
            groupsByPath[path] = group

            if isTopLevelGroup {
                rootGroups.insert(group.reference)
            }
        }
        return group
    }

    private func getVariantGroup(path: Path, inPath: Path) -> PBXVariantGroup {
        let variantGroup: PBXVariantGroup
        if let cachedGroup = variantGroupsByPath[path] {
            variantGroup = cachedGroup
        } else {
            variantGroup = PBXVariantGroup(reference: referenceGenerator.generate(PBXVariantGroup.self, path.byRemovingBase(path: inPath).string),
                                           children: [],
                                           name: path.lastComponent,
                                           sourceTree: .group)
            addObject(variantGroup)
            variantGroupsByPath[path] = variantGroup
        }
        return variantGroup
    }

    private func getSourceChildren(targetSource: TargetSource, dirPath: Path) throws -> [Path] {

        func getSourceExcludes(targetSource: TargetSource, dirPath: Path) -> [Path] {
            return targetSource.excludes.map {
                Path.glob("\(dirPath)/\($0)")
                    .map {
                        guard $0.isDirectory else {
                            return [$0]
                        }

                        return (try? $0.recursiveChildren().filter { $0.isFile }) ?? []
                    }
                    .reduce([], +)
            }
            .reduce([], +)
        }

        let defaultExcludedFiles = [".DS_Store"].map { dirPath + Path($0) }

        let sourcePath = Path(targetSource.path)

        /*
         Exclude following if mentioned in TargetSource.excludes.
         Any path related to source dirPath
         + Pre-defined Excluded files
         */

        let sourceExcludeFilePaths: Set<Path> = Set(getSourceExcludes(targetSource: targetSource, dirPath: sourcePath)
            + defaultExcludedFiles)

        return try dirPath.children()
            .filter {
                if $0.isDirectory {
                    let pathChildren = try $0.children()
                        .filter {
                            return !sourceExcludeFilePaths.contains($0)
                        }

                    return !pathChildren.isEmpty
                } else if $0.isFile {
                    return !sourceExcludeFilePaths.contains($0)
                } else {
                    return false
                }
            }
    }

    private func getGroupSources(targetSource: TargetSource, path: Path, isBaseGroup: Bool) throws -> (sourceFiles: [SourceFile], groups: [PBXGroup]) {

        let children = try getSourceChildren(targetSource: targetSource, dirPath: path)

        let directories = children
            .filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }
            .sorted { $0.lastComponent < $1.lastComponent }

        let filePaths = children
            .filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }
            .sorted { $0.lastComponent < $1.lastComponent }

        let localisedDirectories = children
            .filter { $0.extension == "lproj" }
            .sorted { $0.lastComponent < $1.lastComponent }

        var groupChildren: [String] = filePaths.map { getFileReference(path: $0, inPath: path) }
        var allSourceFiles: [SourceFile] = filePaths.map {
            generateSourceFile(targetSource: targetSource, path: $0)
        }
        var groups: [PBXGroup] = []

        for path in directories {
            let subGroups = try getGroupSources(targetSource: targetSource, path: path, isBaseGroup: false)

            guard !subGroups.sourceFiles.isEmpty else {
                continue
            }

            allSourceFiles += subGroups.sourceFiles

            guard let first = subGroups.groups.first else {
                continue
            }

            groupChildren.append(first.reference)
            groups += subGroups.groups
        }

        // create variant groups of the base localisation first
        var baseLocalisationVariantGroups: [PBXVariantGroup] = []
        if let baseLocalisedDirectory = localisedDirectories.first(where: { $0.lastComponent == "Base.lproj" }) {
            for filePath in try baseLocalisedDirectory.children().sorted() {
                let variantGroup = getVariantGroup(path: filePath, inPath: path)
                groupChildren.append(variantGroup.reference)
                baseLocalisationVariantGroups.append(variantGroup)

                let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, variantGroup.reference), fileRef: variantGroup.reference, settings: nil)
                allSourceFiles.append(SourceFile(path: filePath, fileReference: variantGroup.reference, buildFile: buildFile, buildPhase: .resources))
            }
        }

        // add references to localised resources into base localisation variant groups
        for localisedDirectory in localisedDirectories {
            let localisationName = localisedDirectory.lastComponentWithoutExtension
            for filePath in try localisedDirectory.children().sorted { $0.lastComponent < $1.lastComponent } {
                // find base localisation variant group
                // ex: Foo.strings will be added to Foo.strings or Foo.storyboard variant group
                let variantGroup = baseLocalisationVariantGroups.first { Path($0.name!).lastComponent == filePath.lastComponent } ??
                    baseLocalisationVariantGroups.first { Path($0.name!).lastComponentWithoutExtension == filePath.lastComponentWithoutExtension }

                let fileReference = getFileReference(path: filePath, inPath: path, name: variantGroup != nil ? localisationName : filePath.lastComponent)

                if let variantGroup = variantGroup {
                    if !variantGroup.children.contains(fileReference) {
                        variantGroup.children.append(fileReference)
                    }
                } else {
                    // add SourceFile to group if there is no Base.lproj directory
                    let buildFile = PBXBuildFile(reference: referenceGenerator.generate(PBXBuildFile.self, fileReference),
                                                 fileRef: fileReference,
                                                 settings: nil)
                    allSourceFiles.append(SourceFile(path: filePath, fileReference: fileReference, buildFile: buildFile, buildPhase: .resources))
                    groupChildren.append(fileReference)
                }
            }
        }

        let group = getGroup(path: path, mergingChildren: groupChildren, createIntermediateGroups: spec.options.createIntermediateGroups, isBaseGroup: isBaseGroup)
        if spec.options.createIntermediateGroups {
            createIntermediaGroups(for: group.reference, at: path)
        }

        groups.insert(group, at: 0)
        return (allSourceFiles, groups)
    }

    private func getSourceFiles(targetSource: TargetSource, path: Path) throws -> [SourceFile] {

        let type = targetSource.type ?? (path.isFile || path.extension != nil ? .file : .group)
        let createIntermediateGroups = spec.options.createIntermediateGroups

        var sourceFiles: [SourceFile] = []
        let sourceReference: String
        var sourcePath = path
        switch type {
        case .folder:
            let folderPath = Path(targetSource.path)
            let fileReference = getFileReference(path: folderPath, inPath: spec.basePath, name: targetSource.name ?? folderPath.lastComponent, sourceTree: .sourceRoot)

            if !createIntermediateGroups {
                rootGroups.insert(fileReference)
            }

            let sourceFile = generateSourceFile(targetSource: targetSource, path: folderPath, buildPhase: .resources)

            sourceFiles.append(sourceFile)
            sourceReference = fileReference
        case .file:
            let parentPath = path.parent()
            let fileReference = getFileReference(path: path, inPath: parentPath, name: targetSource.name)

            let sourceFile = generateSourceFile(targetSource: targetSource, path: path)

            let parentGroup = getGroup(path: parentPath, mergingChildren: [fileReference], createIntermediateGroups: createIntermediateGroups, isBaseGroup: true)

            sourcePath = parentPath
            sourceFiles.append(sourceFile)
            sourceReference = parentGroup.reference
        case .group:
            let (groupSourceFiles, groups) = try getGroupSources(targetSource: targetSource, path: path, isBaseGroup: true)
            let group = groups.first!
            if let name = targetSource.name {
                group.name = name
            }

            sourceFiles += groupSourceFiles
            sourceReference = group.reference
        }

        if createIntermediateGroups {
            createIntermediaGroups(for: sourceReference, at: sourcePath)
        }

        return sourceFiles
    }

    // Add groups for all parents recursively
    private func createIntermediaGroups(for groupReference: String, at path: Path) {

        let parentPath = path.parent()
        guard parentPath != spec.basePath && path.string.contains(spec.basePath.string) else {
            // we've reached the top or are out of the root directory
            return
        }

        let hasParentGroup = groupsByPath[parentPath] != nil
        let parentGroup = getGroup(path: parentPath, mergingChildren: [groupReference], createIntermediateGroups: true, isBaseGroup: false)

        if !hasParentGroup {
            createIntermediaGroups(for: parentGroup.reference, at: parentPath)
        }
    }
}
