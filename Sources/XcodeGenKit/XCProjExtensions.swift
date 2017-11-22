import Foundation
import xcproj

public protocol GroupChild: Referenceable {
    var childName: String { get }
    var sortOrder: Int { get }
}

extension PBXFileReference: GroupChild {
    public var childName: String {
        return name ?? path ?? ""
    }

    public var sortOrder: Int {
        return 1
    }
}

extension PBXGroup: GroupChild {
    public var childName: String {
        return name ?? path ?? ""
    }

    public var sortOrder: Int {
        return 0
    }
}

extension PBXVariantGroup: GroupChild {
    public var childName: String {
        return name ?? ""
    }

    public var sortOrder: Int {
        return 1
    }
}

extension PBXProj {

    public func printGroups() -> String {
        guard let project = objects.projects.first?.value, let mainGroup = objects.groups.getReference(project.mainGroup) else {
            return ""
        }
        return printGroup(group: mainGroup)
    }

    public func printGroup(group: PBXGroup) -> String {
        var string = group.childName
        for reference in group.children {
            if let group = objects.groups.getReference(reference) {
                string += "\n 📁  " + printGroup(group: group).replacingOccurrences(of: "\n ", with: "\n    ")
            } else if let fileReference = objects.fileReferences.getReference(reference) {
                string += "\n 📄  " + fileReference.childName
            } else if let variantGroup = objects.variantGroups.getReference(reference) {
                string += "\n 🌎  " + variantGroup.childName
            }
        }
        return string
    }

    public func getGroupChild(reference: String) -> GroupChild? {
        return objects.groups.getReference(reference) ?? objects.fileReferences.getReference(reference) ?? objects.variantGroups.getReference(reference)
    }
}
