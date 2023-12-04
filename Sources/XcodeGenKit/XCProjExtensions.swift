import Foundation
import PathKit
import XcodeProj

extension PBXFileElement {
    public var nameOrPath: String {
        return name ?? path ?? ""
    }

    static func sortByNamePath(_ lhs: PBXFileElement, _ rhs: PBXFileElement) -> Bool {
        return lhs.namePathSortString.localizedStandardCompare(rhs.namePathSortString) == .orderedAscending
    }

    private var namePathSortString: String {
        // This string needs to be unique for all combinations of name & path or the order won't be stable.
        return "\(name ?? path ?? "")\t\(name ?? "")\t\(path ?? "")"
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
                string += "\n 📁 " + printGroup(group: group).replacingOccurrences(of: "\n ", with: "\n    ")
            } else if let fileReference = child as? PBXFileReference {
                string += "\n 📄 " + fileReference.nameOrPath
            } else if let variantGroup = child as? PBXVariantGroup {
                string += "\n 🌎 " + variantGroup.nameOrPath
            } else if let versionGroup = child as? XCVersionGroup {
                string += "\n 🔢 " + versionGroup.nameOrPath
            }
        }
        return string
    }
}

extension Dictionary {

    public var valueArray: [Value] {
        Array(values)
    }
}

extension Xcode {

    public static func fileType(path: Path, productType: PBXProductType? = nil) -> String? {
        guard let fileExtension = path.extension else { return nil }
        switch (fileExtension, productType) {
        // cases that aren't handled (yet) in XcodeProj.
        case ("appex", .extensionKitExtension):
            return "wrapper.extensionkit-extension"
        case ("swiftcrossimport", _):
            return "wrapper.swiftcrossimport"
        case ("xcstrings", _):
            return "text.json.xcstrings"
        default:
            // fallback to XcodeProj defaults
            return Xcode.filetype(extension: fileExtension)
        }
    }

    public static func isDirectoryFileWrapper(path: Path) -> Bool {
        guard path.isDirectory else { return false }
        return fileType(path: path) != nil
    }
}
