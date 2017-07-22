//
//  BuildSetting.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 21/7/17.
//
//

import Foundation
import JSONUtilities
import xcodeproj

public struct TargetBuildSettings: JSONObjectConvertible {

    public let buildSettings: BuildSettings
    public let configSettings: [String: BuildSettings]

    public init(buildSettings: BuildSettings, configSettings: [String: BuildSettings] = [:]) {
        self.buildSettings = buildSettings
        self.configSettings = configSettings
    }

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["$base"] != nil {
            buildSettings = BuildSettings(dictionary: try jsonDictionary.json(atKeyPath: "$base"))
            var configSettings: [String: BuildSettings] = [:]
            for (key, value) in jsonDictionary {
                if key != "baseSettings", let buildSettings = value as? JSONDictionary {
                    configSettings["key"] = BuildSettings(dictionary: buildSettings)
                }
            }
            self.configSettings = configSettings
        } else {
            buildSettings = BuildSettings(dictionary: jsonDictionary)
            configSettings = [:]
        }
    }
}

