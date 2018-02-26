import Foundation
import PathKit
import ProjectSpec
import xcproj

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

    private let spec: ProjectSpec
    var addObjectClosure: (String, PBXObject) -> String

    var targetName: String = ""

    private(set) var knownRegions: Set<String> = []

    init(spec: ProjectSpec, addObjectClosure: @escaping (String, PBXObject) -> String) {
        self.spec = spec
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
        return try sources.flatMap { try getSourceFiles(targetSource: $0, path: spec.basePath + $0.path) }
    }

    // get groups without build files. Use for Project.fileGroups
    func getFileGroups(path: String) throws {
        // TODO: call a seperate function that only creates groups not source files
        _ = try getGroupSources(targetSource: TargetSource(path: path), path: spec.basePath + path, isBaseGroup: true)
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
            settings = ["ATTRIBUTES": ["Public"]]
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
        let createIntermediateGroups = spec.options.createIntermediateGroups

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
        if let fileReference = fileReferencesByPath[path.string.lowercased()] {
            return fileReference
        } else {
            let fileReferencePath = path.byRemovingBase(path: inPath)
            var fileReferenceName: String? = name ?? fileReferencePath.lastComponent
            if fileReferencePath.string == fileReferenceName {
                fileReferenceName = nil
            }
            let lastKnownFileType = lastKnownFileType ?? PBXFileReference.fileType(path: path)
            let fileReference = createObject(
                id: path.byRemovingBase(path: spec.basePath).string,
                PBXFileReference(
                    sourceTree: sourceTree,
                    name: fileReferenceName,
                    lastKnownFileType: lastKnownFileType,
                    path: fileReferencePath.string
                )
            )
            fileReferencesByPath[path.string.lowercased()] = fileReference.reference
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

    private func getGroup(path: Path, name: String? = nil, mergingChildren children: [String], createIntermediateGroups: Bool, isBaseGroup: Bool) -> ObjectReference<PBXGroup> {
        let groupReference: ObjectReference<PBXGroup>

        if let cachedGroup = groupsByPath[path] {
            // only add the children that aren't already in the cachedGroup
            cachedGroup.object.children = Array(Set(cachedGroup.object.children + children))
            groupReference = cachedGroup
        } else {

            // lives outside the spec base path
            let isOutOfBasePath = !path.absolute().string.contains(spec.basePath.absolute().string)

            // has no valid parent paths
            let isRootPath = isOutOfBasePath || path.parent() == spec.basePath

            // is a top level group in the project
            let isTopLevelGroup = (isBaseGroup && !createIntermediateGroups) || isRootPath

            let groupName = name ?? path.lastComponent
            let groupPath = isTopLevelGroup ?
                path.byRemovingBase(path: spec.basePath).string :
                path.lastComponent
            let group = PBXGroup(
                children: children,
                sourceTree: .group,
                name: groupName != groupPath ? groupName : nil,
                path: groupPath
            )
            groupReference = createObject(id: path.byRemovingBase(path: spec.basePath).string, group)
            groupsByPath[path] = groupReference

            if isTopLevelGroup {
                rootGroups.insert(groupReference.reference)
            }
        }
        return groupReference
    }

    private func getVariantGroup(path: Path, inPath: Path) -> ObjectReference<PBXVariantGroup> {
        let variantGroup: ObjectReference<PBXVariantGroup>
        if let cachedGroup = variantGroupsByPath[path] {
            variantGroup = cachedGroup
        } else {
            let group = PBXVariantGroup(
                children: [],
                name: path.lastComponent,
                sourceTree: .group
            )
            variantGroup = createObject(id: path.byRemovingBase(path: spec.basePath).string, group)
            variantGroupsByPath[path] = variantGroup
        }
        return variantGroup
    }

    private func getSourceChildren(targetSource: TargetSource, dirPath: Path) throws -> [Path] {

        func getSourceExcludes(dirPath: Path) -> [Path] {
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

        let rootSourcePath = spec.basePath + targetSource.path

        /*
         Exclude following if mentioned in TargetSource.excludes.
         Any path related to source dirPath
         + Pre-defined Excluded files
         */

        let sourceExcludeFilePaths: Set<Path> = Set(
            getSourceExcludes(dirPath: rootSourcePath)
                + defaultExcludedFiles
        )

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
                findLocalisedDirectory(by: NSLocale.canonicalLanguageIdentifier(from: spec.options.developmentLanguage ?? "en"))
        }()

        knownRegions.formUnion(localisedDirectories.map { $0.lastComponentWithoutExtension })

        // create variant groups of the base localisation first
        var baseLocalisationVariantGroups: [PBXVariantGroup] = []

        if let baseLocalisedDirectory = baseLocalisedDirectory {
            for filePath in try baseLocalisedDirectory.children().sorted() {
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
            for filePath in try localisedDirectory.children().sorted { $0.lastComponent < $1.lastComponent } {
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
            createIntermediateGroups: spec.options.createIntermediateGroups,
            isBaseGroup: isBaseGroup
        )
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
            let fileReference = getFileReference(
                path: folderPath,
                inPath: spec.basePath,
                name: targetSource.name ?? folderPath.lastComponent,
                sourceTree: .sourceRoot,
                lastKnownFileType: "folder"
            )

            if !createIntermediateGroups {
                rootGroups.insert(fileReference)
            }

            let sourceFile = generateSourceFile(targetSource: targetSource, path: folderPath, buildPhase: targetSource.buildPhase?.buildPhase ?? .resources)

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
