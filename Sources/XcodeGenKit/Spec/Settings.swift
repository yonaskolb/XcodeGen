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

public struct Settings: Equatable, JSONObjectConvertible, CustomStringConvertible  {

    public let buildSettings: BuildSettings
    public let configSettings: [String: BuildSettings]

    public init(buildSettings: BuildSettings, configSettings: [String: BuildSettings] = [:]) {
        self.buildSettings = buildSettings
        self.configSettings = configSettings
    }

    public init(dictionary: [String: Any]) {
        self.buildSettings = BuildSettings(dictionary: dictionary)
        self.configSettings = [:]
    }

    static let empty: Settings = Settings(buildSettings: BuildSettings())

    public init(jsonDictionary: JSONDictionary) throws {
        if let configSettings: [String: BuildSettings] = jsonDictionary.json(atKeyPath: "configs") {
            buildSettings = jsonDictionary.json(atKeyPath: "default") ?? [:]
            self.configSettings = configSettings
        } else {
            buildSettings = BuildSettings(dictionary: jsonDictionary)
            configSettings = [:]
        }
    }

    public static func ==(lhs: Settings, rhs: Settings) -> Bool {
        return lhs.buildSettings == rhs.buildSettings && lhs.configSettings == rhs.configSettings
    }

    public var description: String {
        var string: String = ""
        if !buildSettings.dictionary.isEmpty {
            string += buildSettings.description
        }
        for (config, buildSettings) in configSettings {
            if !buildSettings.dictionary.isEmpty {
                string += "\n\(config)\n\t" + buildSettings.description.replacingOccurrences(of: "\n", with: "\n\t")
            }
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

extension BuildSettings: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        self.init(dictionary: jsonDictionary)
    }
}
