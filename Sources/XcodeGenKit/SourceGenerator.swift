import Foundation
import PathKit
import ProjectSpec
import XcodeProj
import XcodeGenCore

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

    func createLocalPackage(path: Path, group: Path?) throws {
        var parentGroup: String = project.options.localPackagesGroup ?? "Packages"
        if let group {
          parentGroup = group.string
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

        if parentGroup == "" {
            rootGroups.insert(fileReference)
        } else {
            let parentGroups = parentGroup.components(separatedBy: "/")
            createParentGroups(parentGroups, for: fileReference)
        }
    }

    /// Collects an array complete of all `SourceFile` objects that make up the target based on the provided `TargetSource` definitions.
    ///
    /// - Parameters:
    ///   - targetType: The type of target that the source files should belong to.
    ///   - sources: The array of sources defined as part of the targets spec.
    ///   - buildPhases: A dictionary containing any build phases that should be applied to source files at specific paths in the event that the associated `TargetSource` didn't already define a `buildPhase`. Values from this dictionary are used in cases where the project generator knows more about a file than the spec/filesystem does (i.e if the file should be treated as the targets Info.plist and so on).
    func getAllSourceFiles(targetType: PBXProductType, sources: [TargetSource], buildPhases: [Path : BuildPhaseSpec]) throws -> [SourceFile] {
        try sources.flatMap { try getSourceFiles(targetType: targetType, targetSource: $0, buildPhases: buildPhases) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        _ = try getSourceFiles(targetType: .none, targetSource: TargetSource(path: path), buildPhases: [:])
    }

    func getFileType(path: Path) -> FileType? {
        if let fileExtension = path.extension {
            return project.options.fileTypes[fileExtension] ?? FileType.defaultFileTypes[fileExtension]
        } else {
            return nil
        }
    }
    
    private func makeDestinationFilters(for path: Path, with filters: [SupportedDestination]?, or inferDestinationFiltersByPath: Bool?) -> [String]? {
        if let filters = filters, !filters.isEmpty {
            return filters.map { $0.string }
        } else if inferDestinationFiltersByPath == true {
            for supportedDestination in SupportedDestination.allCases {
                let regex1 = try? NSRegularExpression(pattern: "\\/\(supportedDestination)\\/", options: .caseInsensitive)
                let regex2 = try? NSRegularExpression(pattern: "\\_\(supportedDestination)\\.swift$", options: .caseInsensitive)
                
                if regex1?.isMatch(to: path.string) == true || regex2?.isMatch(to: path.string) == true {
                    return [supportedDestination.string]
                }
            }
        }
        return nil
    }
    
    func generateSourceFile(targetType: PBXProductType, targetSource: TargetSource, path: Path, fileReference: PBXFileElement? = nil, buildPhases: [Path: BuildPhaseSpec]) -> SourceFile {
        let fileReference = fileReference ?? fileReferencesByPath[path.string.lowercased()]!
        var settings: [String: Any] = [:]
        let fileType = getFileType(path: path)
        var attributes: [String] = targetSource.attributes + (fileType?.attributes ?? [])
        var chosenBuildPhase: BuildPhaseSpec?
        var compilerFlags: String = ""
        let assetTags: [String] = targetSource.resourceTags + (fileType?.resourceTags ?? [])

        let headerVisibility = targetSource.headerVisibility ?? .public

        if let buildPhase = targetSource.buildPhase {
            chosenBuildPhase = buildPhase
        } else if resolvedTargetSourceType(for: targetSource, at: path) == .folder {
            chosenBuildPhase = .resources
        } else if let buildPhase = buildPhases[path] {
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
        
        let platforms = makeDestinationFilters(for: path, with: targetSource.destinationFilters, or: targetSource.inferDestinationFiltersByPath)
        
        let buildFile = PBXBuildFile(file: fileReference, settings: settings.isEmpty ? nil : settings, platformFilters: platforms)
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
            case "swiftcrossimport":
                guard targetType == .framework else { return nil }
                return .copyFiles(BuildPhaseSpec.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "$(PRODUCT_NAME).framework/Modules",
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
            patterns.parallelMap { pattern in
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
    func isIncludedPath(_ path: Path, excludePaths: Set<Path>, includePaths: SortedArray<Path>?) -> Bool {
        return !defaultExcludedFiles.contains(where: { path.lastComponent == $0 })
            && !(path.extension.map(defaultExcludedExtensions.contains) ?? false)
            && !excludePaths.contains(path)
            // If includes is empty, it's included. If it's not empty, the path either needs to match exactly, or it needs to be a direct parent of an included path.
            && (includePaths.flatMap { _isIncludedPathSorted(path, sortedPaths: $0) } ?? true)
    }
    
    private func _isIncludedPathSorted(_ path: Path, sortedPaths: SortedArray<Path>) -> Bool {
        guard let idx = sortedPaths.firstIndex(where: { $0 >= path }) else { return false }
        let foundPath = sortedPaths.value[idx]
        return foundPath.description.hasPrefix(path.description)
    }


    /// Gets all the children paths that aren't excluded
    private func getSourceChildren(targetSource: TargetSource, dirPath: Path, excludePaths: Set<Path>, includePaths: SortedArray<Path>?) throws -> [Path] {
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
        includePaths: SortedArray<Path>?,
        buildPhases: [Path: BuildPhaseSpec]
    ) throws -> (sourceFiles: [SourceFile], groups: [PBXGroup]) {

        let children = try getSourceChildren(targetSource: targetSource, dirPath: path, excludePaths: excludePaths, includePaths: includePaths)

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups
        let nonLocalizedChildren = children.filter { $0.extension != "lproj" }
        let stringCatalogChildren = children.filter { $0.extension == "xcstrings" }

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
            generateSourceFile(targetType: targetType, targetSource: targetSource, path: $0, buildPhases: buildPhases)
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
                includePaths: includePaths,
                buildPhases: buildPhases
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
        
        // XCode 15 - Detect known regions from locales present in string catalogs
        
        let stringCatalogsLocales = stringCatalogChildren
            .compactMap { StringCatalog(from: $0) }
            .reduce(Set<String>(), { partialResult, stringCatalog in
                partialResult.union(stringCatalog.includedLocales)
            })
        knownRegions.formUnion(stringCatalogsLocales)

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
                                                    fileReference: variantGroup,
                                                    buildPhases: buildPhases)
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
                                                        fileReference: fileReference,
                                                        buildPhases: buildPhases)
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
    private func getSourceFiles(targetType: PBXProductType, targetSource: TargetSource, buildPhases: [Path: BuildPhaseSpec]) throws -> [SourceFile] {

        // generate excluded paths
        let path = project.basePath + targetSource.path
        let excludePaths = getSourceMatches(targetSource: targetSource, patterns: targetSource.excludes)
        // generate included paths. Excluded paths will override this.
        let includePaths = targetSource.includes.isEmpty ? nil : getSourceMatches(targetSource: targetSource, patterns: targetSource.includes)

        let type = resolvedTargetSourceType(for: targetSource, at: path)

        let customParentGroups = (targetSource.group ?? "").split(separator: "/").map { String($0) }
        let hasCustomParent = !customParentGroups.isEmpty

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups

        var sourceFiles: [SourceFile] = []
        let sourceReference: PBXFileElement
        var sourcePath = path
        switch type {
        case .folder:
            let fileReference = getFileReference(
                path: path,
                inPath: project.basePath,
                name: targetSource.name ?? path.lastComponent,
                sourceTree: .sourceRoot,
                lastKnownFileType: "folder"
            )

            if !(createIntermediateGroups || hasCustomParent) || path.parent() == project.basePath {
                rootGroups.insert(fileReference)
            }

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: path, buildPhases: buildPhases)

            sourceFiles.append(sourceFile)
            sourceReference = fileReference
        case .file:
            let parentPath = path.parent()
            let fileReference = getFileReference(path: path, inPath: parentPath, name: targetSource.name)

            let sourceFile = generateSourceFile(targetType: targetType, targetSource: targetSource, path: path, buildPhases: buildPhases)

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
                includePaths: includePaths.flatMap(SortedArray.init(_:)),
                buildPhases: buildPhases
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

    /// Returns the resolved `SourceType` for a given `TargetSource`.
    ///
    /// While `TargetSource` declares `type`, its optional and in the event that the value is not defined then we must resolve a sensible default based on the path of the source.
    private func resolvedTargetSourceType(for targetSource: TargetSource, at path: Path) -> SourceType {
        return targetSource.type ?? (path.isFile || path.extension != nil ? .file : .group)
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
