import Foundation
import xcodeproj
import PathKit

extension PBXFileElement {

    public var nameOrPath: String {
        return name ?? path ?? ""
    }
}

extension PBXProj {

    public func printGroups() -> String {
        guard let project = objects.projects.first?.value,
            let mainGroup = objects.groups.getReference(project.mainGroupReference) else {
            return ""
        }
        return printGroup(group: mainGroup)
    }

    public func printGroup(group: PBXGroup) -> String {
        var string = group.nameOrPath
        for reference in group.childrenReferences {
            if let group = objects.groups.getReference(reference) {
                string += "\n 📁  " + printGroup(group: group).replacingOccurrences(of: "\n ", with: "\n    ")
            } else if let fileReference = objects.fileReferences.getReference(reference) {
                string += "\n 📄  " + fileReference.nameOrPath
            } else if let variantGroup = objects.variantGroups.getReference(reference) {
                string += "\n 🌎  " + variantGroup.nameOrPath
            } else if let versionGroup = objects.versionGroups.getReference(reference) {
                string += "\n 🔢  " + versionGroup.nameOrPath
            }
        }
        return string
    }
}

extension PBXObjects {

    public func getFileElement(reference: PBXObjectReference) -> PBXFileElement? {
        return groups[reference] ??
        fileReferences[reference] ??
        versionGroups[reference] ??
        variantGroups[reference]
    }
}

extension Dictionary {

    public var valueArray: Array<Value> {
        return Array(values)
    }
}

extension Dictionary where Key == PBXObjectReference {

    public func getReference(_ reference: PBXObjectReference) -> Value? {
        return self[reference]
    }
}

extension Xcode {

    public static func fileType(path: Path) -> String? {
        return path.extension.flatMap { Xcode.filetype(extension: $0) }
    }
}
