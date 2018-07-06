import Foundation
import PathKit
import ProjectSpec
import xcodeproj

struct SourceFile {
    let path: Path
    let fileReference: String
    let buildFile: PBXBuildFile
    let buildPhase: BuildPhase?
}

class SourceGenerator {

    var rootGroups: Set<String> = []
    private var fileReferencesByPath: [String: String] = [:]
    private var groupsByPath: [Path: ObjectReference<PBXGroup>] = [:]
    private var variantGroupsByPath: [Path: ObjectReference<PBXVariantGroup>] = [:]

    private let project: Project
    var addObjectClosure: (String, PBXObject) -> String
    var targetSourceExcludePaths: Set<Path> = []
    var defaultExcludedFiles = [
        ".DS_Store",
    ]

    var targetName: String = ""

    private(set) var knownRegions: Set<String> = []

    init(project: Project, addObjectClosure: @escaping (String, PBXObject) -> String) {
        self.project = project
        self.addObjectClosure = addObjectClosure
    }

    func addObject(id: String, _ object: PBXObject) -> String {
        return addObjectClosure(id, object)
    }

    func createObject<T: PBXObject>(id: String, _ object: T) -> ObjectReference<T> {
        let reference = addObject(id: id, object)
        return ObjectReference(reference: reference, object: object)
    }

    func getAllSourceFiles(sources: [TargetSource]) throws -> [SourceFile] {
        return try sources.flatMap { try getSourceFiles(targetSource: $0, path: project.basePath + $0.path) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        let fullPath = project.basePath + path
        _ = try getSourceFiles(targetSource: TargetSource(path: path), path: fullPath)
    }

    func generateSourceFile(targetSource: TargetSource, path: Path, buildPhase: BuildPhase? = nil) -> SourceFile {
        let fileReference = fileReferencesByPath[path.string.lowercased()]!
        var settings: [String: Any] = [:]
        let chosenBuildPhase: BuildPhase?

        if let buildPhase = buildPhase {
            chosenBuildPhase = buildPhase
        } else if let buildPhase = targetSource.buildPhase {
            chosenBuildPhase = buildPhase.buildPhase
        } else {
            chosenBuildPhase = getDefaultBuildPhase(for: path)
        }

        if chosenBuildPhase == .headers {
            let headerVisibility = targetSource.headerVisibility ?? .public
            if headerVisibility != .project {
                // Xcode doesn't write the default of project
                settings["ATTRIBUTES"] = [headerVisibility.settingName]
            }
        }
        if targetSource.compilerFlags.count > 0 {
            settings["COMPILER_FLAGS"] = targetSource.compilerFlags.joined(separator: " ")
        }

        let buildFile = PBXBuildFile(fileRef: fileReference, settings: settings.isEmpty ? nil : settings)
        return SourceFile(
            path: path,
            fileReference: fileReference,
            buildFile: buildFile,
            buildPhase: chosenBuildPhase
        )
    }

    func getContainedFileReference(path: Path) -> String {
        let createIntermediateGroups = project.options.createIntermediateGroups

        let parentPath = path.parent()
        let fileReference = getFileReference(path: path, inPath: parentPath)
        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileReference],
            createIntermediateGroups: createIntermediateGroups,
            isBaseGroup: true
        )

        if createIntermediateGroups {
            createIntermediaGroups(for: parentGroup.reference, at: parentPath)
        }
        return fileReference
    }

    func getFileReference(path: Path, inPath: Path, name: String? = nil, sourceTree: PBXSourceTree = .group, lastKnownFileType: String? = nil) -> String {
        let fileReferenceKey = path.string.lowercased()
        if let fileReference = fileReferencesByPath[fileReferenceKey] {
            return fileReference
        } else {
            let fileReferencePath = path.byRemovingBase(path: inPath)
            var fileReferenceName: String? = name ?? fileReferencePath.lastComponent
            if fileReferencePath.string == fileReferenceName {
                fileReferenceName = nil
            }
            let lastKnownFileType = lastKnownFileType ?? PBXFileReference.fileType(path: path)

            if path.extension == "xcdatamodeld" {
                let models = (try? path.children()) ?? []
                let modelFileReference = models
                    .filter { $0.extension == "xcdatamodel" }
                    .sorted()
                    .map { path in
                        createObject(
                            id: path.byRemovingBase(path: project.basePath).string,
                            PBXFileReference(
                                sourceTree: .group,
                                lastKnownFileType: "wrapper.xcdatamodel",
                                path: path.lastComponent
                            )
                        )
                    }
                let versionGroup = addObject(id: fileReferencePath.string, XCVersionGroup(
                    currentVersion: modelFileReference.first?.reference,
                    path: fileReferencePath.string,
                    sourceTree: sourceTree,
                    versionGroupType: "wrapper.xcdatamodel",
                    children: modelFileReference.map { $0.reference }
                ))
                fileReferencesByPath[fileReferenceKey] = versionGroup
                return versionGroup
            } else {
                let fileReference = createObject(
                    id: path.byRemovingBase(path: project.basePath).string,
                    PBXFileReference(
                        sourceTree: sourceTree,
                        name: fileReferenceName,
                        lastKnownFileType: lastKnownFileType,
                        path: fileReferencePath.string
                    )
                )
                fileReferencesByPath[fileReferenceKey] = fileReference.reference
                return fileReference.reference
            }
        }
    }

    /// returns a default build phase for a given path. This is based off the filename
    private func getDefaultBuildPhase(for path: Path) -> BuildPhase? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "swift", "m", "mm", "cpp", "c", "cc", "S", "xcdatamodeld": return .sources
            case "h", "hh", "hpp", "ipp", "tpp", "hxx", "def": return .headers
            case "framework": return .frameworks
            case "xcconfig", "entitlements", "gpx", "lproj", "apns": return nil
            default: return .resources
            }
        }
        return nil
    }

    /// Create a group or return an existing one at the path.
    /// Any merged children are added to a new group or merged into an existing one.
    private func getGroup(path: Path, name: String? = nil, mergingChildren children: [String], createIntermediateGroups: Bool, isBaseGroup: Bool) -> ObjectReference<PBXGroup> {
        let groupReference: ObjectReference<PBXGroup>

        if let cachedGroup = groupsByPath[path] {
            // only add the children that aren't already in the cachedGroup
            cachedGroup.object.children = Array(Set(cachedGroup.object.children + children))
            groupReference = cachedGroup
        } else {

            // lives outside the project base path
            let isOutOfBasePath = !path.absolute().string.contains(project.basePath.absolute().string)

            // has no valid parent paths
            let isRootPath = isOutOfBasePath || path.parent() == project.basePath

            // is a top level group in the project
            let isTopLevelGroup = (isBaseGroup && !createIntermediateGroups) || isRootPath

            let groupName = name ?? path.lastComponent
            let groupPath = isTopLevelGroup ?
                path.byRemovingBase(path: project.basePath).string :
                path.lastComponent
            let group = PBXGroup(
                children: children,
                sourceTree: .group,
                name: groupName != groupPath ? groupName : nil,
                path: groupPath
            )
            groupReference = createObject(id: path.byRemovingBase(path: project.basePath).string, group)
            groupsByPath[path] = groupReference

            if isTopLevelGroup {
                rootGroups.insert(groupReference.reference)
            }
        }
        return groupReference
    }

    /// Creates a variant group or returns an existing one at the path
    private func getVariantGroup(path: Path, inPath: Path) -> ObjectReference<PBXVariantGroup> {
        let variantGroup: ObjectReference<PBXVariantGroup>
        if let cachedGroup = variantGroupsByPath[path] {
            variantGroup = cachedGroup
        } else {
            let group = PBXVariantGroup(
                children: [],
                sourceTree: .group,
                name: path.lastComponent
            )
            variantGroup = createObject(id: path.byRemovingBase(path: project.basePath).string, group)
            variantGroupsByPath[path] = variantGroup
        }
        return variantGroup
    }

    /// Collects all the excluded paths within the targetSource
    private func getSourceExcludes(targetSource: TargetSource) -> Set<Path> {
        let rootSourcePath = project.basePath + targetSource.path

        return Set(
            targetSource.excludes.map {
                Path.glob("\(rootSourcePath)/\($0)")
                    .map {
                        guard $0.isDirectory else {
                            return [$0]
                        }

                        return (try? $0.recursiveChildren()) ?? []
                    }
                    .reduce([], +)
            }
            .reduce([], +)
        )
    }

    /// Checks whether the path is not in any default or TargetSource excludes
    func isIncludedPath(_ path: Path) -> Bool {
        return !defaultExcludedFiles.contains(where: { path.lastComponent.contains($0) })
            && !targetSourceExcludePaths.contains(path)
    }

    /// Gets all the children paths that aren't excluded
    private func getSourceChildren(targetSource: TargetSource, dirPath: Path) throws -> [Path] {
        return try dirPath.children()
            .filter {
                if $0.isDirectory {
                    let children = try $0.children().filter(isIncludedPath)
                    return !children.isEmpty
                } else if $0.isFile {
                    return isIncludedPath($0)
                } else {
                    return false
                }
            }
    }

    /// creates all the source files and groups they belong to for a given targetSource
    private func getGroupSources(targetSource: TargetSource, path: Path, isBaseGroup: Bool)
        throws -> (sourceFiles: [SourceFile], groups: [ObjectReference<PBXGroup>]) {

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
        var groups: [ObjectReference<PBXGroup>] = []

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

        // find the base localised directory
        let baseLocalisedDirectory: Path? = {
            func findLocalisedDirectory(by languageId: String) -> Path? {
                return localisedDirectories.first { $0.lastComponent == "\(languageId).lproj" }
            }
            return findLocalisedDirectory(by: "Base") ??
                findLocalisedDirectory(by: NSLocale.canonicalLanguageIdentifier(from: project.options.developmentLanguage ?? "en"))
        }()

        knownRegions.formUnion(localisedDirectories.map { $0.lastComponentWithoutExtension })

        // create variant groups of the base localisation first
        var baseLocalisationVariantGroups: [PBXVariantGroup] = []

        if let baseLocalisedDirectory = baseLocalisedDirectory {
            for filePath in try baseLocalisedDirectory.children()
                .filter(isIncludedPath)
                .sorted() {
                let variantGroup = getVariantGroup(path: filePath, inPath: path)
                groupChildren.append(variantGroup.reference)
                baseLocalisationVariantGroups.append(variantGroup.object)

                let sourceFile = SourceFile(
                    path: filePath,
                    fileReference: variantGroup.reference,
                    buildFile: PBXBuildFile(fileRef: variantGroup.reference),
                    buildPhase: .resources
                )
                allSourceFiles.append(sourceFile)
            }
        }

        // add references to localised resources into base localisation variant groups
        for localisedDirectory in localisedDirectories {
            let localisationName = localisedDirectory.lastComponentWithoutExtension
            for filePath in try localisedDirectory.children()
                .filter(isIncludedPath)
                .sorted { $0.lastComponent < $1.lastComponent } {
                // find base localisation variant group
                // ex: Foo.strings will be added to Foo.strings or Foo.storyboard variant group
                let variantGroup = baseLocalisationVariantGroups
                    .first {
                        Path($0.name!).lastComponent == filePath.lastComponent

                    } ?? baseLocalisationVariantGroups.first {
                        Path($0.name!).lastComponentWithoutExtension == filePath.lastComponentWithoutExtension
                    }

                let fileReference = getFileReference(
                    path: filePath,
                    inPath: path,
                    name: variantGroup != nil ? localisationName : filePath.lastComponent
                )

                if let variantGroup = variantGroup {
                    if !variantGroup.children.contains(fileReference) {
                        variantGroup.children.append(fileReference)
                    }
                } else {
                    // add SourceFile to group if there is no Base.lproj directory
                    let sourceFile = SourceFile(
                        path: filePath,
                        fileReference: fileReference,
                        buildFile: PBXBuildFile(fileRef: fileReference),
                        buildPhase: .resources
                    )
                    allSourceFiles.append(sourceFile)
                    groupChildren.append(fileReference)
                }
            }
        }

        let group = getGroup(
            path: path,
            mergingChildren: groupChildren,
            createIntermediateGroups: project.options.createIntermediateGroups,
            isBaseGroup: isBaseGroup
        )
        if project.options.createIntermediateGroups {
            createIntermediaGroups(for: group.reference, at: path)
        }

        groups.insert(group, at: 0)
        return (allSourceFiles, groups)
    }

    /// creates source files
    private func getSourceFiles(targetSource: TargetSource, path: Path) throws -> [SourceFile] {

        // generate excluded paths
        targetSourceExcludePaths = getSourceExcludes(targetSource: targetSource)

        let type = targetSource.type ?? (path.isFile || path.extension != nil ? .file : .group)
        let createIntermediateGroups = project.options.createIntermediateGroups

        var sourceFiles: [SourceFile] = []
        let sourceReference: String
        var sourcePath = path
        switch type {
        case .folder:
            let folderPath = Path(targetSource.path)
            let fileReference = getFileReference(
                path: folderPath,
                inPath: project.basePath,
                name: targetSource.name ?? folderPath.lastComponent,
                sourceTree: .sourceRoot,
                lastKnownFileType: "folder"
            )

            if !createIntermediateGroups || path.parent() == project.basePath {
                rootGroups.insert(fileReference)
            }

            let buildPhase: BuildPhase?
            if let targetBuildPhase = targetSource.buildPhase {
                buildPhase = targetBuildPhase.buildPhase
            } else {
                buildPhase = .resources
            }

            let sourceFile = generateSourceFile(targetSource: targetSource, path: folderPath, buildPhase: buildPhase)

            sourceFiles.append(sourceFile)
            sourceReference = fileReference
        case .file:
            let parentPath = path.parent()
            let fileReference = getFileReference(path: path, inPath: parentPath, name: targetSource.name)

            let sourceFile = generateSourceFile(targetSource: targetSource, path: path)

            if parentPath == project.basePath {
                sourcePath = path
                sourceReference = fileReference
                rootGroups.insert(fileReference)
            } else {
                let parentGroup = getGroup(path: parentPath, mergingChildren: [fileReference], createIntermediateGroups: createIntermediateGroups, isBaseGroup: true)
                sourcePath = parentPath
                sourceReference = parentGroup.reference
            }
            sourceFiles.append(sourceFile)

        case .group:
            let (groupSourceFiles, groups) = try getGroupSources(targetSource: targetSource, path: path, isBaseGroup: true)
            let group = groups.first!
            if let name = targetSource.name {
                group.object.name = name
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
        guard parentPath != project.basePath && path.string.contains(project.basePath.string) else {
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
