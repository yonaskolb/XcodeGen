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

public struct Config: Equatable {
    public var name: String
    public var type: ConfigType?
    public var settings: BuildSettings
    public var settingPresets: [String]

    public init(name: String, type: ConfigType? = nil, settings: BuildSettings = .empty, settingPresets: [String] = []) {
        self.name = name
        self.settings = settings
        self.settingPresets = settingPresets
        self.type = type
    }

    public static func ==(lhs: Config, rhs: Config) -> Bool {
        return lhs.name == rhs.name &&
        lhs.type == rhs.type &&
        lhs.settings == rhs.settings &&
        lhs.settingPresets == rhs.settingPresets
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
        settings = BuildSettings(dictionary: jsonDictionary.json(atKeyPath: "settings") ?? [:])
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? []
    }
}
