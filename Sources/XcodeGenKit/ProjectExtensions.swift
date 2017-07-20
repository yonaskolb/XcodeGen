//
//  ProjectExtensions.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/7/17.
//
//

import Foundation
import xcodeproj

extension Array where Element: ProjectElement {

    var referenceList: [String] {
        return map { $0.reference }
    }

    var referenceSet: Set<String> {
        return Set(referenceList)
    }
}
