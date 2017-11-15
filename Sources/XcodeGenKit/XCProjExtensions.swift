//
//  XCProjExtensions.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 11/11/17.
//

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
        guard let project = projects.first, let mainGroup = groups.getReference(project.mainGroup) else {
            return ""
        }
        return printGroup(group: mainGroup)
    }

    public func printGroup(group: PBXGroup) -> String {
        var string = group.childName
        for reference in group.children {
            if let group = groups.getReference(reference) {
                string += "\n 📁  " + printGroup(group: group).replacingOccurrences(of: "\n ", with: "\n    ")
            } else if let fileReference = fileReferences.getReference(reference) {
                string += "\n 📄  " + fileReference.childName
            } else if let variantGroup = variantGroups.getReference(reference) {
                string += "\n 🌎  " + variantGroup.childName
            }
        }
        return string
    }

    public func getGroupChild(reference: String) -> GroupChild? {
        return groups.getReference(reference) ?? fileReferences.getReference(reference) ?? variantGroups.getReference(reference)
    }
}
