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
    public let configSettings: [String: Settings]
    public let presets: [String]

    public init(buildSettings: BuildSettings = .empty, configSettings: [String: Settings] = [:], presets: [String] = []) {
        self.buildSettings = buildSettings
        self.configSettings = configSettings
        self.presets = presets
    }

    public init(dictionary: [String: Any]) {
        buildSettings = BuildSettings(dictionary: dictionary)
        configSettings = [:]
        presets = []
    }

    static let empty: Settings = Settings(dictionary: [:])

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["configs"] != nil || jsonDictionary["presets"] != nil || jsonDictionary["base"] != nil {
            presets = jsonDictionary.json(atKeyPath: "presets") ?? []
            let buildSettingsDictionary: JSONDictionary = jsonDictionary.json(atKeyPath: "base") ?? [:]
            buildSettings = BuildSettings(dictionary: buildSettingsDictionary)
            configSettings = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        } else {
            buildSettings = BuildSettings(dictionary: jsonDictionary)
            configSettings = [:]
            presets = []
        }
    }

    public static func ==(lhs: Settings, rhs: Settings) -> Bool {
        return lhs.buildSettings == rhs.buildSettings &&
            lhs.configSettings == rhs.configSettings &&
            lhs.presets == rhs.presets
    }

    public var description: String {
        var string: String = ""
        if !buildSettings.dictionary.isEmpty {
            let buildSettingDescription = buildSettings.description
            if !configSettings.isEmpty || !presets.isEmpty {
                string += "base:\n  " + buildSettingDescription.replacingOccurrences(of: "(.)\n", with: "$1\n  ", options: .regularExpression, range: nil)
            } else {
                string += buildSettingDescription
            }
        }
        if !configSettings.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            for (config, buildSettings) in configSettings {
                if !buildSettings.description.isEmpty {
                    string += "configs:\n"
                    string += "  \(config):\n    " + buildSettings.description.replacingOccurrences(of: "(.)\n", with: "$1\n    ", options: .regularExpression, range: nil)
                }
            }
        }
        if !presets.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            string += "presets:\n  \(presets.joined(separator: "\n  "))"
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

extension BuildSettings {

    public convenience init(path: Path) throws {
        let content: String = try path.read()
        if content == "" {
            self.init(dictionary: [:])
            return
        }
        let yaml = try Yams.load(yaml: content)
        guard let jsonDictionary = yaml as? JSONDictionary else {
            throw JSONUtilsError.fileNotAJSONDictionary
        }
        self.init(dictionary: jsonDictionary)
    }
}
