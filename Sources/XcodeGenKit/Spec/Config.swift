//
//  Config.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 20/7/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct Config {
    public var name: String
    public var type: String?
    public var buildSettingGroups: [BuildSettingGroup]
    public var settings: BuildSettings
}

extension Config: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        type = jsonDictionary.json(atKeyPath: "type")
        buildSettingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        settings = BuildSettings(dictionary: jsonDictionary.json(atKeyPath: "settings") ?? [:])
    }
}
