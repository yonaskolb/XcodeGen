//
//  Spec.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/5/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities
import PathKit
import Yams

public struct Spec {

    public var name: String
    public var targets: [Target]
    public var settings: Settings
    public var settingPresets: [String: SettingPreset]
    public var configs: [Config]
    public var schemes: [Scheme]

    public init(name: String, configs: [Config] = [], targets: [Target] = [], settings: Settings = .empty, settingPresets: [String: SettingPreset] = [:], schemes: [Scheme] = []) {
        self.name = name
        self.targets = targets
        self.configs = configs
        self.settings = settings
        self.settingPresets = settingPresets
        self.schemes = schemes
    }

    public func getTarget(_ targetName: String) -> Target? {
        return targets.first { $0.name == targetName }
    }

    public func getConfig(_ configName: String) -> Config? {
        return configs.first { $0.name == configName }
    }
}

extension Spec {

    public init(path: Path) throws {
        let string: String = try path.read()
        try self.init(path: path, string: string)
    }

    public init(path: Path, string: String) throws {
        let yaml = try Yams.load(yaml: string)
        let json = yaml as! JSONDictionary

        try self.init(jsonDictionary: json)
    }

    public init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        configs = try jsonDictionary.json(atKeyPath: "configs")
        if jsonDictionary["targets"] == nil {
            targets = []
        } else {
            targets = try jsonDictionary.json(atKeyPath: "targets", invalidItemBehaviour: .fail)
        }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
    }
}
