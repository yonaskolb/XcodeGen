//
//  ProjectExtensions.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/7/17.
//
//

import Foundation
import xcodeproj
import PathKit

extension Array where Element: ProjectElement {

    public var referenceList: [String] {
        return map { $0.reference }
    }

    public var referenceSet: Set<String> {
        return Set(referenceList)
    }
}

extension BuildSettings: CustomStringConvertible {

    public init() {
        dictionary = [:]
    }

    public static let empty = BuildSettings()

    public func merged(_ buildSettings: BuildSettings) -> BuildSettings {
        var mergedSettings = self
        mergedSettings.merge(buildSettings)
        return mergedSettings
    }

    public mutating func merge(_ buildSettings: BuildSettings) {
        for (key, value) in buildSettings.dictionary {
            dictionary[key] = value
        }
    }

    public var description: String {
        return dictionary.map { "\($0) = \($1)" }.joined(separator: "\n")
    }
}

public func +=(lhs: inout BuildSettings, rhs: BuildSettings?) {
    guard let rhs = rhs else { return }
    lhs.merge(rhs)
}

extension PBXProductType {

    init?(string: String) {
        if let type = PBXProductType(rawValue: string) {
            self = type
        } else if let type = PBXProductType(rawValue: "com.apple.product-type.\(string)") {
            self = type
        } else {
            return nil
        }
    }

    public var isExtension: Bool {
        return fileExtension == "appex"
    }
}
