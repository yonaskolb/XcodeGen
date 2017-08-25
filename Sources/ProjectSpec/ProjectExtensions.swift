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

extension Array where Element: Referenceable {

    public var referenceList: [String] {
        return map { $0.reference }
    }

    public var referenceSet: Set<String> {
        return Set(referenceList)
    }
}

extension BuildSettings: CustomStringConvertible {

    public convenience init() {
        self.init(dictionary: [:])
    }

    public static let empty = BuildSettings()

    public func merge(_ buildSettings: BuildSettings) {
        for (key, value) in buildSettings.dictionary {
            dictionary[key] = value
        }
    }

    public var description: String {
        return dictionary.map { "\($0) = \($1)" }.joined(separator: "\n")
    }
}

public func +=(lhs: BuildSettings, rhs: BuildSettings?) {
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

    public var isApp: Bool {
        return fileExtension == "app"
    }

    public var name: String {
        return rawValue.replacingOccurrences(of: "com.apple.product-type.", with: "")
    }
}
