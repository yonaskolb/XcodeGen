import Foundation
import PathKit
import XcodeProj

extension PBXFileElement {

    public var nameOrPath: String {
        return name ?? path ?? ""
    }
}

extension PBXProj {

    public func printGroups() -> String {
        guard let project = projects.first,
            let mainGroup = project.mainGroup else {
            return ""
        }
        return printGroup(group: mainGroup)
    }

    public func printGroup(group: PBXGroup) -> String {
        var string = group.nameOrPath
        for child in group.children {
            if let group = child as? PBXGroup {
                string += "\n 📁  " + printGroup(group: group).replacingOccurrences(of: "\n ", with: "\n    ")
            } else if let fileReference = child as? PBXFileReference {
                string += "\n 📄  " + fileReference.nameOrPath
            } else if let variantGroup = child as? PBXVariantGroup {
                string += "\n 🌎  " + variantGroup.nameOrPath
            } else if let versionGroup = child as? XCVersionGroup {
                string += "\n 🔢  " + versionGroup.nameOrPath
            }
        }
        return string
    }
}

extension Dictionary {

    public var valueArray: Array<Value> {
        return Array(values)
    }
}

extension Xcode {

    public static func fileType(path: Path) -> String? {
        return path.extension.flatMap { Xcode.filetype(extension: $0) }
    }
}
