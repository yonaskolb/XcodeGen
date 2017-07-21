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

    let buildSettings: BuildSettings
    let configSettings: [String: BuildSettings]

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

