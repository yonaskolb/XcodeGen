import Foundation
import PathKit
import ProjectSpec
import xcodeproj

struct SourceFile {
    let path: Path
    let fileReference: PBXFileElement
    let buildFile: PBXBuildFile
    let buildPhase: TargetSource.BuildPhase?
}

class SourceGenerator {

    var rootGroups: Set<PBXFileElement> = []
    private var fileReferencesByPath: [String: PBXFileElement] = [:]
    private var groupsByPath: [Path: PBXGroup] = [:]
    private var variantGroupsByPath: [Path: PBXVariantGroup] = [:]

    private let project: Project
    let pbxProj: PBXProj

    var targetSourceExcludePaths: Set<Path> = []
    var defaultExcludedFiles = [
        ".DS_Store",
    ]

    private(set) var knownRegions: Set<String> = []

    init(project: Project, pbxProj: PBXProj) {
        self.project = project
        self.pbxProj = pbxProj
    }

    func addObject<T: PBXObject>(_ object: T, context: String? = nil) -> T {
        pbxProj.add(object: object)
        object.context = context
        return object
    }

    func getAllSourceFiles(targetType: PBXProductType, sources: [TargetSource]) throws -> [SourceFile] {
        return try sources.flatMap { try getSourceFiles(targetType: targetType, targetSource: $0, path: project.basePath + $0.path) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        let fullPath = project.basePath + path
        _ = try getSourceFiles(targetType: .none, targetSource: TargetSource(path: path), path: fullPath)
    }

    func generateSourceFile(targetType: PBXProductType, targetSource: TargetSource, path: Path, buildPhase: TargetSource.BuildPhase? = nil) -> SourceFile {
        let fileReference = fileReferencesByPath[path.string.lowercased()]!
        var settings: [String: Any] = [:]
        var chosenBuildPhase: TargetSource.BuildPhase?

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
                chosenBuildPhase = .copyFiles(TargetSource.BuildPhase.CopyFilesSettings(
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
                settings["ATTRIBUTES"] = [headerVisibility.settingName]
            }
        }
        if chosenBuildPhase == .sources && targetSource.compilerFlags.count > 0 {
            settings["COMPILER_FLAGS"] = targetSource.compilerFlags.joined(separator: " ")
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
    private func getDefaultBuildPhase(for path: Path, targetType: PBXProductType) -> TargetSource.BuildPhase? {
        if path.lastComponent == "Info.plist" {
            return nil
        }
        if let fileExtension = path.extension {
            switch fileExtension {
            case "swift",
                 "m",
                 "mm",
                 "cpp",
                 "c",
                 "cc",
                 "S",
                 "xcdatamodeld",
                 "intentdefinition",
                 "metal",
                 "mlmodel":
                return .sources
            case "h",
                 "hh",
                 "hpp",
                 "ipp",
                 "tpp",
                 "hxx",
                 "def":
                return .headers
            case "modulemap":
                guard targetType == .staticLibrary else { return nil }
                return .copyFiles(TargetSource.BuildPhase.CopyFilesSettings(
                    destination: .productsDirectory,
                    subpath: "include/$(PRODUCT_NAME)",
                    phaseOrder: .preCompile
                ))
            case "framework":
                return .frameworks
            case "xpc":
                return .copyFiles(.xpcServices)
            case "xcconfig",
                 "entitlements",
                 "gpx",
                 "lproj",
                 "xcfilelist",
                 "apns":
                return nil
            default:
                return .resources
            }
        }
        return nil
    }

    /// Create a group or return an existing one at the path.
    /// Any merged children are added to a new group or merged into an existing one.
    private func getGroup(path: Path, name: String? = nil, mergingChildren children: [PBXFileElement], createIntermediateGroups: Bool, isBaseGroup: Bool) -> PBXGroup {
        let groupReference: PBXGroup

        if let cachedGroup = groupsByPath[path] {
            for child in children {
                // only add the children that aren't already in the cachedGroup
                if !cachedGroup.children.contains(child) {
                    cachedGroup.children.append(child)
                }
            }
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
                ((try? path.relativePath(from: project.basePath)) ?? path).string :
                path.lastComponent
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
                    let children = try $0.children()

                    if children.isEmpty {
                        return project.options.generateEmptyDirectories
                    }

                    return !children.filter(isIncludedPath).isEmpty
                } else if $0.isFile {
                    return isIncludedPath($0)
                } else {
                    return false
                }
            }
    }

    /// creates all the source files and groups they belong to for a given targetSource
    private func getGroupSources(targetType: PBXProductType, targetSource: TargetSource, path: Path, isBaseGroup: Bool)
        throws -> (sourceFiles: [SourceFile], groups: [PBXGroup]) {

        let children = try getSourceChildren(targetSource: targetSource, dirPath: path)

        let directories = children
            .filter { $0.isDirectory && $0.extension == nil && $0.extension != "lproj" }

        let filePaths = children
            .filter { $0.isFile || $0.extension != nil && $0.extension != "lproj" }

        let localisedDirectories = children
            .filter { $0.extension == "lproj" }

        var groupChildren: [PBXFileElement] = filePaths.map { getFileReference(path: $0, inPath: path) }
        var allSourceFiles: [SourceFile] = filePaths.map {
            generateSourceFile(targetType: targetType, targetSource: targetSource, path: $0)
        }
        var groups: [PBXGroup] = []

        for path in directories {
            let subGroups = try getGroupSources(targetType: targetType, targetSource: targetSource, path: path, isBaseGroup: false)

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
                groupChildren.append(variantGroup)
                baseLocalisationVariantGroups.append(variantGroup)

                let sourceFile = SourceFile(
                    path: filePath,
                    fileReference: variantGroup,
                    buildFile: PBXBuildFile(file: variantGroup),
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
                        buildFile: PBXBuildFile(file: fileReference),
                        buildPhase: .resources
                    )
                    allSourceFiles.append(sourceFile)
                    groupChildren.append(fileReference)
                }
            }
        }

        let createIntermediateGroups = targetSource.createIntermediateGroups ?? project.options.createIntermediateGroups

        let group = getGroup(
            path: path,
            mergingChildren: groupChildren,
            createIntermediateGroups: createIntermediateGroups,
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

        if targetSource.optional && !Path(targetSource.path).exists {
            // Is optional so if it doesn't exist just return an empty array
            return []
        }

        // generate excluded paths
        targetSourceExcludePaths = getSourceExcludes(targetSource: targetSource)

        let type = targetSource.type ?? (path.isFile || path.extension != nil ? .file : .group)
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

            if !createIntermediateGroups || path.parent() == project.basePath {
                rootGroups.insert(fileReference)
            }

            let buildPhase: TargetSource.BuildPhase?
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

            if parentPath == project.basePath {
                sourcePath = path
                sourceReference = fileReference
                rootGroups.insert(fileReference)
            } else {
                let parentGroup = getGroup(path: parentPath, mergingChildren: [fileReference], createIntermediateGroups: createIntermediateGroups, isBaseGroup: true)
                sourcePath = parentPath
                sourceReference = parentGroup
            }
            sourceFiles.append(sourceFile)

        case .group:
            let (groupSourceFiles, groups) = try getGroupSources(targetType: targetType, targetSource: targetSource, path: path, isBaseGroup: true)
            let group = groups.first!
            if let name = targetSource.name {
                group.name = name
            }

            sourceFiles += groupSourceFiles
            sourceReference = group
        }

        if createIntermediateGroups {
            createIntermediaGroups(for: sourceReference, at: sourcePath)
        }

        return sourceFiles
    }

    // Add groups for all parents recursively
    private func createIntermediaGroups(for fileElement: PBXFileElement, at path: Path) {

        let parentPath = path.parent()
        guard parentPath != project.basePath && path.string.contains(project.basePath.string) else {
            // we've reached the top or are out of the root directory
            return
        }

        let hasParentGroup = groupsByPath[parentPath] != nil
        let parentGroup = getGroup(path: parentPath, mergingChildren: [fileElement], createIntermediateGroups: true, isBaseGroup: false)

        if !hasParentGroup {
            createIntermediaGroups(for: parentGroup, at: parentPath)
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
