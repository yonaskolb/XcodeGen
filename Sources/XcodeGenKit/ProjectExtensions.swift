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

extension BuildSettings {

    init() {
        dictionary = [:]
    }

    static var empty = BuildSettings()

    func merged(_ buildSettings: BuildSettings) -> BuildSettings {
        var mergedSettings = self
        mergedSettings.merge(buildSettings)
        return mergedSettings
    }

    mutating func merge(_ buildSettings: BuildSettings) {
        for (key, value) in buildSettings.dictionary {
            dictionary[key] = value
        }
    }
}

func +=( lhs: inout BuildSettings, rhs: BuildSettings?) {
    guard let rhs = rhs else { return }
    lhs.merge(rhs)
}
