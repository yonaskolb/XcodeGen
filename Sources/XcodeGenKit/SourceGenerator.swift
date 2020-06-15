import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import Core

struct SourceFile {
    let path: Path
    let fileReference: PBXFileElement
    let buildFile: PBXBuildFile
    let buildPhase: BuildPhaseSpec?
}

class SourceGenerator {

    var rootGroups: Set<PBXFileElement> = []
    private let projectDirectory: Path?
    private var fileReferencesByPath: [String: PBXFileElement] = [:]
    private var groupsByPath: [Path: PBXGroup] = [:]
    private var variantGroupsByPath: [Path: PBXVariantGroup] = [:]
    private var localPackageGroup: PBXGroup?

    private let project: Project
    let pbxProj: PBXProj

    private var defaultExcludedFiles = [
        ".DS_Store",
    ]
    private let defaultExcludedExtensions = [
        "orig",
    ]

    private(set) var knownRegions: Set<String> = []

    init(project: Project, pbxProj: PBXProj, projectDirectory: Path?) {
        self.project = project
        self.pbxProj = pbxProj
        self.projectDirectory = projectDirectory
    }

    private func resolveGroupPath(_ path: Path, isTopLevelGroup: Bool) -> String {
        if isTopLevelGroup, let relativePath = try? path.relativePath(from: projectDirectory ?? project.basePath).string {
            return relativePath
        } else {
            return path.lastComponent
        }
    }

    @discardableResult
    func addObject<T: PBXObject>(_ object: T, context: String? = nil) -> T {
        pbxProj.add(object: object)
        object.context = context
        return object
    }

    func createLocalPackage(path: Path) throws {

        if localPackageGroup == nil {
            let groupName = project.options.localPackagesGroup ?? "Packages"
            localPackageGroup = addObject(PBXGroup(sourceTree: .sourceRoot, name: groupName))
            rootGroups.insert(localPackageGroup!)
        }

        let absolutePath = project.basePath + path.normalize()

        // Get the local package's relative path from the project root
        let fileReferencePath = try? absolutePath.relativePath(from: projectDirectory ?? project.basePath).string

        let fileReference = addObject(
            PBXFileReference(
                sourceTree: .sourceRoot,
                name: absolutePath.lastComponent,
                lastKnownFileType: "folder",
                path: fileReferencePath
            )
        )
        localPackageGroup!.children.append(fileReference)
    }

    func getAllSourceFiles(targetType: PBXProductType, sources: [TargetSource]) throws -> [SourceFile] {
        try sources.flatMap { try getSourceFiles(targetType: targetType, targetSource: $0, path: project.basePath + $0.path) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        let fullPath = project.basePath + path
        _ = try getSourceFiles(targetType: .none, targetSource: TargetSource(path: path), path: fullPath)
    }

    func getFileType(path: Path) -> FileType? {
        if let fileExtension = path.extension {
            return project.options.fileTypes[fileExtension] ?? FileType.defaultFileTypes[fileExtension]
        } else {
            return nil
        }
    }

    func generateSourceFile(targetType: PBXProductType, targetSource: TargetSource, path: Path, buildPhase: BuildPhaseSpec? = nil, fileReference: PBXFileElement? = nil) -> SourceFile {
        let fileReference = fileReference ?? fileReferencesByPath[path.string.lowercased()]!
        var settings: [String: Any] = [:]
        let fileType = getFileType(path: path)
        var attributes: [String] = targetSource.attributes + (fileType?.attributes ?? [])
        var chosenBuildPhase: BuildPhaseSpec?
        var compilerFlags: String = ""
        let assetTags: [String] = targetSource.resourceTags + (fileType?.resourceTags ?? [])

        let headerVisibility = targetSource.headerVisibility ?? .public

        if let buildPhase = buildPhase {
            chosenBuildPhase = buildPhase
        } else if let buildPhase = targetSource.buildPhase {
            chosenBuildPhase = buildPhase
        } else {
            chosenBuildPhase = getDefaultBuildPhase(for: path, targetType: targetType)
        }

        if chosenBuildPhase == .headers && targetType == .staticLibrary {
            // Static libraries don't support the header build phase
            // For public headers they need to be copied
            if headerVisibility == .public {
                chosenBuildPhase = .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "include/$(PRODUCT_NAME)",
                    phaseOrder: .preCompile
                ))
            } else {
                chosenBuildPhase = nil
            }
        }

        if chosenBuildPhase == .headers {
            if headerVisibility != .project {
                // Xcode doesn't write the default of project
                attributes.append(headerVisibility.settingName)
            }
        }

        if let flags = fileType?.compilerFlags {
            compilerFlags += flags.joined(separator: " ")
        }

        if !targetSource.compilerFlags.isEmpty {
            if !compilerFlags.isEmpty {
                compilerFlags += " "
            }
            compilerFlags += targetSource.compilerFlags.joined(separator: " ")
        }

        if chosenBuildPhase == .sources && !compilerFlags.isEmpty {
            settings["COMPILER_FLAGS"] = compilerFlags
        }

        if !attributes.isEmpty {
            settings["ATTRIBUTES"] = attributes
        }
        
        if chosenBuildPhase == .resources && !assetTags.isEmpty {
            settings["ASSET_TAGS"] = assetTags
        }

        let buildFile = PBXBuildFile(file: fileReference, settings: settings.isEmpty ? nil : settings)
        return SourceFile(
            path: path,
            fileReference: fileReference,
            buildFile: buildFile,
            buildPhase: chosenBuildPhase
        )
    }

    func getContainedFileReference(path: Path) -> PBXFileElement {
        let createIntermediateGroups = project.options.createIntermediateGroups

        let parentPath = path.parent()
        let fileReference = getFileReference(path: path, inPath: parentPath)
        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileReference],
            createIntermediateGroups: createIntermediateGroups,
            hasCustomParent: false,
            isBaseGroup: true
        )

        if createIntermediateGroups {
            createIntermediaGroups(for: parentGroup, at: parentPath)
        }
        return fileReference
    }

    func getFileReference(path: Path, inPath: Path, name: String? = nil, sourceTree: PBXSourceTree = .group, lastKnownFileType: String? = nil) -> PBXFileElement {
        let fileReferenceKey = path.string.lowercased()
        if let fileReference = fileReferencesByPath[fileReferenceKey] {
            return fileReference
        } else {
            let fileReferencePath = (try? path.relativePath(from: inPath)) ?? path
            var fileReferenceName: String? = name ?? fileReferencePath.lastComponent
            if fileReferencePath.string == fileReferenceName {
                fileReferenceName = nil
            }
            let lastKnownFileType = lastKnownFileType ?? Xcode.fileType(path: path)

            if path.extension == "xcdatamodeld" {
                let versionedModels = (try? path.children()) ?? []

                // Sort the versions alphabetically
                let sortedPaths = versionedModels
                    .filter { $0.extension == "xcdatamodel" }
                    .sorted { $0.string.localizedStandardCompare($1.string) == .orderedAscending }

                let modelFileReferences =
                    sortedPaths.map { path in
                        addObject(
                            PBXFileReference(
                                sourceTree: .group,
                                lastKnownFileType: "wrapper.xcdatamodel",
                                path: path.lastComponent
                            )
                        )
                    }
                // If no current version path is found we fall back to alphabetical
                // order by taking the last item in the sortedPaths array
                let currentVersionPath = findCurrentCoreDataModelVersionPath(using: versionedModels) ?? sortedPaths.last
                let currentVersion: PBXFileReference? = {
                    guard let indexOf = sortedPaths.firstIndex(where: { $0 == currentVersionPath }) else { return nil }
                    return modelFileReferences[indexOf]
                }()
                let versionGroup = addObject(XCVersionGroup(
                    currentVersion: currentVersion,
                    path: fileReferencePath.string,
                    sourceTree: sourceTree,
                    versionGroupType: "wrapper.xcdatamodel",
                    children: modelFileReferences
                ))
                fileReferencesByPath[fileReferenceKey] = versionGroup
                return versionGroup
            } else {
                // For all extensions other than `xcdatamodeld`
                let fileReference = addObject(
                    PBXFileReference(
                        sourceTree: sourceTree,
                        name: fileReferenceName,
                        lastKnownFileType: lastKnownFileType,
                        path: fileReferencePath.string
                    )
                )
                fileReferencesByPath[fileReferenceKey] = fileReference
                return fileReference
            }
        }
    }

    /// returns a default build phase for a given path. This is based off the filename
    private func getDefaultBuildPhase(for path: Path, targetType: PBXProductType) -> BuildPhaseSpec? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let buildPhase = getFileType(path: path)?.buildPhase {
            return buildPhase
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "modulemap":
                guard targetType == .staticLibrary else { return nil }
                return .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "include/$(PRODUCT_NAME)",
                    phaseOrder: .preCompile
                ))
            default:
                return .resources
            }
        }
        return nil
    }

    /// Create a group or return an existing one at the path.
    /// Any merged children are added to a new group or merged into an existing one.
    private func getGroup(path: Path, name: String? = nil, mergingChildren children: [PBXFileElement], createIntermediateGroups: Bool, hasCustomParent: Bool, isBaseGroup: Bool) -> PBXGroup {
        let groupReference: PBXGroup

        if let cachedGroup = groupsByPath[path] {
            var cachedGroupChildren = cachedGroup.children
            for child in children {
                // only add the children that aren't already in the cachedGroup
                // Check equality by path and sourceTree because XcodeProj.PBXObject.== is very slow.
                if !cachedGroupChildren.contains(where: { $0.name == child.name && $0.path == child.path && $0.sourceTree == child.sourceTree }) {
                    cachedGroupChildren.append(child)
                    child.parent = cachedGroup
                }
            }
            cachedGroup.children = cachedGroupChildren
            groupReference = cachedGroup
        } else {

            // lives outside the project base path
            let isOutOfBasePath = !path.absolute().string.contains(project.basePath.absolute().string)

            // whether the given path is a strict parent of the project base path
            // e.g. foo/bar is a parent of foo/bar/baz, but not foo/baz
            let isParentOfBasePath = isOutOfBasePath && ((try? path.isParent(of: project.basePath)) == true)

            // has no valid parent paths
            let isRootPath = (isBaseGroup && isOutOfBasePath && isParentOfBasePath) || path.parent() == project.basePath

            // is a top level group in the project
            let isTopLevelGroup = !hasCustomParent && ((isBaseGroup && !createIntermediateGroups) || isRootPath || isParentOfBasePath)

            let groupName = name ?? path.lastComponent

            let groupPath = resolveGroupPath(path, isTopLevelGroup: hasCustomParent || isTopLevelGroup)

            let group = PBXGroup(
                children: children,
                sourceTree: .group,
                name: groupName != groupPath ? groupName : nil,
                path: groupPath
            )
            groupReference = addObject(group)
            groupsByPath[path] = groupReference

            if isTopLevelGroup {
                rootGroups.insert(groupReference)
            }
        }
        return groupReference
    }

    /// Creates a variant group or returns an existing one at the path
    private func getVariantGroup(path: Path, inPath: Path) -> PBXVariantGroup {
        let variantGroup: PBXVariantGroup
        if let cachedGroup = variantGroupsByPath[path] {
            variantGroup = cachedGroup
        } else {
            let group = PBXVariantGroup(
                sourceTree: .group,
                name: path.lastComponent
            )
            variantGroup = addObject(group)
            variantGroupsByPath[path] = variantGroup
        }
        return variantGroup
    }

    /// Collects all the excluded paths within the targetSource
    private func getSourceMatches(targetSource: TargetSource, patterns: [String]) -> Set<Path> {
        let rootSourcePath = project.basePath + targetSource.path

        return Set(
            patterns.map { pattern in
                guard !pattern.isEmpty else { return [] }
                return Glob(pattern: "\(rootSourcePath)/\(pattern)")
                    .map { Path($0) }
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
    func isIncludedPath(_ path: Path, excludePaths: Set<Path>, includePaths: Set<Path>) -> Bool {
        !defaultExcludedFiles.contains(where: { path.lastComponent.contains($0) })
            && !(path.extension.map(defaultExcludedExtensions.contains) ?? false)
            && !excludePaths.contains(path)
            // If includes is empty, it's included. If it's not empty, the path either needs to match exactly, or it needs to be a direct parent of an included path.
            && (includePaths.isEmpty || includePaths.contains(where: { includedFile in
                if path == includedFile { return true }
                return includedFile.description.contains(path.description)
            }))
    }

    /// Gets all the children paths that aren't excluded
    private func getSourceChildren(targetSource: TargetSource, dirPath: Path, excludePaths: Set<Path>, includePaths: Set<Path>) throws -> [Path] {
        try dirPath.children()
            .filter {
                if $0.isDirectory {
                    let children = try $0.children()

                    if children.isEmpty {
                        return project.options.generateEmptyDirectories
                    }

                    return !children
                        .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                        .isEmpty
                } else if $0.isFile {
                    return self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths)
                } else {
                    return false
                }
            }
    }

    /// creates all the source files and groups they belong to for a given targetSource
    private func getGroupSources(
        targetType: PBXProductType,
        targetSource: TargetSource,
        path: Path,
        isBaseGroup: Bool,
        hasCustomParent: Bool,
        excludePaths: Set<Path>,
        includePaths: Set<Path>
    ) throws -> (sourceFiles: [SourceFile], groups: [PBXGroup]) {

        let children = try getSourceChildren(targetSource: targetSource, dirPath: path, excludePaths: excludePaths, includePaths: includePaths)

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups
        let nonLocalizedChildren = children.filter { $0.extension != "lproj" }

        let directories = nonLocalizedChildren
            .filter {
                if let fileType = getFileType(path: $0) {
                    return !fileType.file
                } else {
                    return $0.isDirectory && !Xcode.isDirectoryFileWrapper(path: $0)
                }
            }

        let filePaths = nonLocalizedChildren
            .filter {
                if let fileType = getFileType(path: $0) {
                    return fileType.file
                } else {
                    return $0.isFile || $0.isDirectory && Xcode.isDirectoryFileWrapper(path: $0)
                }
            }

        let localisedDirectories = children
            .filter { $0.extension == "lproj" }

        var groupChildren: [PBXFileElement] = filePaths.map { getFileReference(path: $0, inPath: path) }
        var allSourceFiles: [SourceFile] = filePaths.map {
            generateSourceFile(targetType: targetType, targetSource: targetSource, path: $0)
        }
        var groups: [PBXGroup] = []

        for path in directories {

            let subGroups = try getGroupSources(
                targetType: targetType,
                targetSource: targetSource,
                path: path,
                isBaseGroup: false,
                hasCustomParent: false,
                excludePaths: excludePaths,
                includePaths: includePaths
            )

            guard !subGroups.sourceFiles.isEmpty || project.options.generateEmptyDirectories else {
                continue
            }

            allSourceFiles += subGroups.sourceFiles

            if let firstGroup = subGroups.groups.first {
                groupChildren.append(firstGroup)
                groups += subGroups.groups
            } else if project.options.generateEmptyDirectories {
                groups += subGroups.groups
            }
        }

        // find the base localised directory
        let baseLocalisedDirectory: Path? = {
            func findLocalisedDirectory(by languageId: String) -> Path? {
                localisedDirectories.first { $0.lastComponent == "\(languageId).lproj" }
            }
            return findLocalisedDirectory(by: "Base") ??
                findLocalisedDirectory(by: NSLocale.canonicalLanguageIdentifier(from: project.options.developmentLanguage ?? "en"))
        }()

        knownRegions.formUnion(localisedDirectories.map { $0.lastComponentWithoutExtension })

        // create variant groups of the base localisation first
        var baseLocalisationVariantGroups: [PBXVariantGroup] = []

        if let baseLocalisedDirectory = baseLocalisedDirectory {
            let filePaths = try baseLocalisedDirectory.children()
                .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                .sorted()
            for filePath in filePaths {
                let variantGroup = getVariantGroup(path: filePath, inPath: path)
                groupChildren.append(variantGroup)
                baseLocalisationVariantGroups.append(variantGroup)

                let sourceFile = generateSourceFile(targetType: targetType,
                                                    targetSource: targetSource,
                                                    path: filePath,
                                                    fileReference: variantGroup)
                allSourceFiles.append(sourceFile)
            }
        }

        // add references to localised resources into base localisation variant groups
        for localisedDirectory in localisedDirectories {
            let localisationName = localisedDirectory.lastComponentWithoutExtension
            let filePaths = try localisedDirectory.children()
                .filter { self.isIncludedPath($0, excludePaths: excludePaths, includePaths: includePaths) }
                .sorted { $0.lastComponent < $1.lastComponent }
            for filePath in filePaths {
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
                    let sourceFile = generateSourceFile(targetType: targetType,
                                                        targetSource: targetSource,
                                                        path: filePath,
                                                        fileReference: fileReference)
                    allSourceFiles.append(sourceFile)
                    groupChildren.append(fileReference)
                }
            }
        }

        let group = getGroup(
            path: path,
            mergingChildren: groupChildren,
            createIntermediateGroups: createIntermediateGroups,
            hasCustomParent: hasCustomParent,
            isBaseGroup: isBaseGroup
        )
        if createIntermediateGroups {
            createIntermediaGroups(for: group, at: path)
        }

        groups.insert(group, at: 0)
        return (allSourceFiles, groups)
    }

    /// creates source files
    private func getSourceFiles(targetType: PBXProductType, targetSource: TargetSource, path: Path) throws -> [SourceFile] {

        // generate excluded paths
        let excludePaths = getSourceMatches(targetSource: targetSource, patterns: targetSource.excludes)
        // generate included paths. Excluded paths will override this.
        let includePaths = getSourceMatches(targetSource: targetSource, patterns: targetSource.includes)

        let type = targetSource.type ?? (path.isFile || path.extension != nil ? .file : .group)

        let customParentGroups = (targetSource.group ?? "").split(separator: "/").map { String($0) }
        let hasCustomParent = !customParentGroups.isEmpty

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups

        var sourceFiles: [SourceFile] = []
        let sourceReference: PBXFileElement
        var sourcePath = path
        switch type {
        case .folder:
            let folderPath = project.basePath + Path(targetSource.path)
            let fileReference = getFileReference(
                path: folderPath,
                inPath: project.basePath,
                name: targetSource.name ?? folderPath.lastComponent,
                sourceTree: .sourceRoot,
                lastKnownFileType: "folder"
            )

            if !(createIntermediateGroups || hasCustomParent) || path.parent() == project.basePath {
                rootGroups.insert(fileReference)
            }

            let buildPhase: BuildPhaseSpec?
            if let targetBuildPhase = targetSource.buildPhase {
                buildPhase = targetBuildPhase
            } else {
                buildPhase = .resources
            }

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: folderPath, buildPhase: buildPhase)

            sourceFiles.append(sourceFile)
            sourceReference = fileReference
        case .file:
            let parentPath = path.parent()
            let fileReference = getFileReference(path: path, inPath: parentPath, name: targetSource.name)

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: path)

            if hasCustomParent {
                sourcePath = path
                sourceReference = fileReference
            } else if parentPath == project.basePath {
                sourcePath = path
                sourceReference = fileReference
                rootGroups.insert(fileReference)
            } else {
                let parentGroup = getGroup(
                    path: parentPath,
                    mergingChildren: [fileReference],
                    createIntermediateGroups: createIntermediateGroups,
                    hasCustomParent: hasCustomParent,
                    isBaseGroup: true
                )
                sourcePath = parentPath
                sourceReference = parentGroup
            }
            sourceFiles.append(sourceFile)

        case .group:
            if targetSource.optional && !Path(targetSource.path).exists {
                // This group is missing, so if's optional just return an empty array
                return []
            }

            let (groupSourceFiles, groups) = try getGroupSources(
                targetType: targetType,
                targetSource: targetSource,
                path: path,
                isBaseGroup: true,
                hasCustomParent: hasCustomParent,
                excludePaths: excludePaths,
                includePaths: includePaths
            )

            let group = groups.first!
            if let name = targetSource.name {
                group.name = name
            }

            sourceFiles += groupSourceFiles
            sourceReference = group
        }

        if hasCustomParent {
            createParentGroups(customParentGroups, for: sourceReference)
            try makePathRelative(for: sourceReference, at: path)
        } else if createIntermediateGroups {
            createIntermediaGroups(for: sourceReference, at: sourcePath)
        }

        return sourceFiles
    }

    private func createParentGroups(_ parentGroups: [String], for fileElement: PBXFileElement) {
        guard let parentName = parentGroups.last else {
            return
        }

        let parentPath = project.basePath + Path(parentGroups.joined(separator: "/"))
        let parentPathExists = parentPath.exists
        let parentGroupAlreadyExists = groupsByPath[parentPath] != nil

        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileElement],
            createIntermediateGroups: false,
            hasCustomParent: false,
            isBaseGroup: parentGroups.count == 1
        )

        // As this path is a custom group, remove the path reference
        if !parentPathExists {
            parentGroup.name = String(parentName)
            parentGroup.path = nil
        }

        if !parentGroupAlreadyExists {
            createParentGroups(parentGroups.dropLast(), for: parentGroup)
        }
    }

    // Add groups for all parents recursively
    private func createIntermediaGroups(for fileElement: PBXFileElement, at path: Path) {

        let parentPath = path.parent()
        guard parentPath != project.basePath else {
            // we've reached the top
            return
        }

        let hasParentGroup = groupsByPath[parentPath] != nil
        if !hasParentGroup {
            do {
                // if the path is a parent of the project base path (or if calculating that fails)
                // do not create a parent group
                // e.g. for project path foo/bar/baz
                //  - create foo/baz
                //  - create baz/
                //  - do not create foo
                let pathIsParentOfProject = try path.isParent(of: project.basePath)
                if pathIsParentOfProject { return }
            } catch {
                return
            }
        }
        let parentGroup = getGroup(
            path: parentPath,
            mergingChildren: [fileElement],
            createIntermediateGroups: true,
            hasCustomParent: false,
            isBaseGroup: false
        )

        if !hasParentGroup {
            createIntermediaGroups(for: parentGroup, at: parentPath)
        }
    }

    // Make the fileElement path and name relative to its parents aggregated paths
    private func makePathRelative(for fileElement: PBXFileElement, at path: Path) throws {
        // This makes the fileElement path relative to its parent and not to the project. Xcode then rebuilds the actual
        // path for the file based on the hierarchy this fileElement lives in.
        var paths: [String] = []
        var element: PBXFileElement = fileElement
        while true {
            guard let parent = element.parent else { break }

            if let path = parent.path {
                paths.insert(path, at: 0)
            }

            element = parent
        }

        let completePath = project.basePath + Path(paths.joined(separator: "/"))
        let relativePath = try path.relativePath(from: completePath)
        let relativePathString = relativePath.string

        if relativePathString != fileElement.path {
            fileElement.path = relativePathString
            fileElement.name = relativePath.lastComponent
        }
    }

    private func findCurrentCoreDataModelVersionPath(using versionedModels: [Path]) -> Path? {
        // Find and parse the current version model stored in the .xccurrentversion file
        guard
            let versionPath = versionedModels.first(where: { $0.lastComponent == ".xccurrentversion" }),
            let data = try? versionPath.read(),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
            let versionString = plist["_XCCurrentVersionName"] as? String else {
            return nil
        }
        return versionedModels.first(where: { $0.lastComponent == versionString })
    }
}
