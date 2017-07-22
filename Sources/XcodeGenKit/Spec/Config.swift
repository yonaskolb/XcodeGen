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
    public var type: ConfigType?
    public var buildSettingGroups: [BuildSettingGroup]
    public var buildSettings: BuildSettings

    public init(name: String, type: ConfigType? = nil, buildSettingGroups: [BuildSettingGroup] = [], buildSettings: BuildSettings = .init()) {
        self.name = name
        self.buildSettingGroups = buildSettingGroups
        self.buildSettings = buildSettings
        self.type = type
    }
}


public enum ConfigType: String {
    case debug
    case release
}


extension Config: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        type = jsonDictionary.json(atKeyPath: "type")
        buildSettingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        buildSettings = BuildSettings(dictionary: jsonDictionary.json(atKeyPath: "buildSettings") ?? [:])
    }
}
