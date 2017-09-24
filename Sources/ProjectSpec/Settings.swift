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
import PathKit
import Yams
public struct Settings: Equatable, JSONObjectConvertible, CustomStringConvertible {

    public let buildSettings: BuildSettings
    public let configurationSettings: [String: Settings]
    public let groups: [String]

    public init(buildSettings: BuildSettings = [:], configurationSettings: [String: Settings] = [:], groups: [String] = []) {
        self.buildSettings = buildSettings
        self.configurationSettings = configurationSettings
        self.groups = groups
    }

    public init(dictionary: [String: Any]) {
        buildSettings = dictionary
        configurationSettings = [:]
        groups = []
    }

    public static let empty: Settings = Settings(dictionary: [:])

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["configurations"] != nil || jsonDictionary["groups"] != nil || jsonDictionary["base"] != nil {
            groups = jsonDictionary.json(atKeyPath: "groups") ?? jsonDictionary.json(atKeyPath: "presets") ?? []
            let buildSettingsDictionary: JSONDictionary = jsonDictionary.json(atKeyPath: "base") ?? [:]
            buildSettings = buildSettingsDictionary
            configurationSettings = jsonDictionary.json(atKeyPath: "configurations") ?? [:]
        } else {
            buildSettings = jsonDictionary
            configurationSettings = [:]
            groups = []
        }
    }

    public static func ==(lhs: Settings, rhs: Settings) -> Bool {
        return NSDictionary(dictionary: lhs.buildSettings).isEqual(to: rhs.buildSettings) &&
            lhs.configurationSettings == rhs.configurationSettings &&
            lhs.groups == rhs.groups
    }

    public var description: String {
        var string: String = ""
        if !buildSettings.isEmpty {
            let buildSettingDescription = buildSettings.map { "\($0) = \($1)" }.joined(separator: "\n")
            if !configurationSettings.isEmpty || !groups.isEmpty {
                string += "base:\n  " + buildSettingDescription.replacingOccurrences(of: "(.)\n", with: "$1\n  ", options: .regularExpression, range: nil)
            } else {
                string += buildSettingDescription
            }
        }
        if !configurationSettings.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            for (configuration, buildSettings) in configurationSettings {
                if !buildSettings.description.isEmpty {
                    string += "configurations:\n"
                    string += "  \(configuration):\n    " + buildSettings.description.replacingOccurrences(of: "(.)\n", with: "$1\n    ", options: .regularExpression, range: nil)
                }
            }
        }
        if !groups.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            string += "groups:\n  \(groups.joined(separator: "\n  "))"
        }
        return string
    }
}

extension Settings: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, Any)...) {
        var dictionary: [String: Any] = [:]
        elements.forEach { dictionary[$0.0] = $0.1 }
        self.init(dictionary: dictionary)
    }
}
