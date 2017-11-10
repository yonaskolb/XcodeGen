//
//  XCProjExtensions.swift
//  XcodeGenKit
//
//  Created by Yonas Kolb on 11/11/17.
//

import Foundation
import xcproj

protocol GroupChild: Referenceable {
    var childName: String { get }
    var sortOrder: Int { get }
}

extension PBXFileReference: GroupChild {
    public var childName: String {
        return name ?? path ?? ""
    }

    var sortOrder: Int {
        return 1
    }
}

extension PBXGroup: GroupChild {
    public var childName: String {
        return name ?? path ?? ""
    }

    var sortOrder: Int {
        return 0
    }
}

extension PBXVariantGroup: GroupChild {
    public var childName: String {
        return name ?? ""
    }

    var sortOrder: Int {
        return 2
    }
}
