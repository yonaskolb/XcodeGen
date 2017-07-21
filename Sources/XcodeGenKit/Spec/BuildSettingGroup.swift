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
    public var buildSettings: BuildSettings

    public init(name: String, buildSettings: BuildSettings) {
        self.name = name
        self.buildSettings = buildSettings
    }
}

extension BuildSettingGroup: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        self.buildSettings = BuildSettings(dictionary: jsonDictionary)
    }
}
