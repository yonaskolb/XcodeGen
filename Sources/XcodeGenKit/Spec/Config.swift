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
    public var buildSettingGroups: [BuildSettingGroup]
    public var settings: [String: String]
}

extension Config: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        buildSettingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? [:]
    }
}
