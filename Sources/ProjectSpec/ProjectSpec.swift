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

public struct ProjectSpec {

    public var name: String
    public var targets: [Target]
    public var settings: Settings
    public var settingPresets: [String: Settings]
    public var configs: [Config]
    public var schemes: [Scheme]
    public var options: Options

    public struct Options {
        public var carthageBuildPath: String?

        public init(carthageBuildPath: String? = nil) {
            self.carthageBuildPath = carthageBuildPath
        }
    }

    public init(name: String, configs: [Config] = [], targets: [Target] = [], settings: Settings = .empty, settingPresets: [String: Settings] = [:], schemes: [Scheme] = [], options: Options = Options()) {
        self.name = name
        self.targets = targets
        self.configs = configs
        self.settings = settings
        self.settingPresets = settingPresets
        self.schemes = schemes
        self.options = options
    }

    public func getTarget(_ targetName: String) -> Target? {
        return targets.first { $0.name == targetName }
    }

    public func getConfig(_ configName: String) -> Config? {
        return configs.first { $0.name == configName }
    }
}

extension ProjectSpec: Equatable {

    public static func ==(lhs: ProjectSpec, rhs: ProjectSpec) -> Bool {
        return lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
            lhs.settings == rhs.settings &&
            lhs.settingPresets == rhs.settingPresets &&
            lhs.configs == rhs.configs &&
            lhs.schemes == rhs.schemes &&
            lhs.options == rhs.options
    }
}

extension ProjectSpec.Options: Equatable {

    public static func ==(lhs: ProjectSpec.Options, rhs: ProjectSpec.Options) -> Bool {
        return lhs.carthageBuildPath == rhs.carthageBuildPath
    }
}

extension ProjectSpec {

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
        let configs: [String: String] = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        self.configs = configs.map { Config(name: $0, type: ConfigType(rawValue: $1)) }
        if jsonDictionary["targets"] == nil {
            targets = []
        } else {
            targets = try jsonDictionary.json(atKeyPath: "targets", invalidItemBehaviour: .fail)
        }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        if jsonDictionary["options"] != nil {
            options = try jsonDictionary.json(atKeyPath: "options")
        } else {
            options = Options()
        }
    }
}

extension ProjectSpec.Options: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
    }
}
