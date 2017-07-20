//
//  BuildSettings.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 20/7/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct BuildSettingGroup {
    public var name: String
    public var buildSettings: [String: String]
}

extension BuildSettingGroup: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        buildSettings = [:]
        for (key, value) in jsonDictionary {
            buildSettings[key] = String(describing: value)
        }
    }
}
