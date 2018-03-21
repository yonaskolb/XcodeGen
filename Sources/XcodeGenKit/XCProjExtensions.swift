import Foundation
import xcproj

extension PBXFileElement {

    public var nameOrPath: String {
        return name ?? path ?? ""
    }

    public var sortOrder: Int {
        if type(of: self).isa == "PBXGroup" {
            return 0
        } else {
            return 1
        }
    }
}

extension PBXProj {

    public func printGroups() -> String {
        guard let project = objects.projects.first?.value,
            let mainGroup = objects.groups.getReference(project.mainGroup) else {
            return ""
        }
        return printGroup(group: mainGroup)
    }

    public func printGroup(group: PBXGroup) -> String {
        var string = group.nameOrPath
        for reference in group.children {
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
