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
    public var settingGroups: [String: Settings]
    public var configurations: [Configuration]
    public var schemes: [Scheme]
    public var options: Options
    public var attributes: [String: Any]

    public struct Options {
        public var carthageBuildPath: String?

        public init(carthageBuildPath: String? = nil) {
            self.carthageBuildPath = carthageBuildPath
        }
    }

    public init(name: String, configurations: [Configuration] = [], targets: [Target] = [], settings: Settings = .empty, settingGroups: [String: Settings] = [:], schemes: [Scheme] = [], options: Options = Options(), attributes: [String: Any] = [:]) {
        self.name = name
        self.targets = targets
        self.configurations = configurations
        self.settings = settings
        self.settingGroups = settingGroups
        self.schemes = schemes
        self.options = options
        self.attributes = attributes
    }

    public func getTarget(_ targetName: String) -> Target? {
        return targets.first { $0.name == targetName }
    }

    public func getConfiguration(_ configurationName: String) -> Configuration? {
        return configurations.first { $0.name == configurationName }
    }
}

extension ProjectSpec: Equatable {

    public static func ==(lhs: ProjectSpec, rhs: ProjectSpec) -> Bool {
        return lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
            lhs.settings == rhs.settings &&
            lhs.settingGroups == rhs.settingGroups &&
            lhs.configurations == rhs.configurations &&
            lhs.schemes == rhs.schemes &&
            lhs.options == rhs.options
    }
}

extension ProjectSpec.Options: Equatable {

    public static func ==(lhs: ProjectSpec.Options, rhs: ProjectSpec.Options) -> Bool {
        return lhs.carthageBuildPath == rhs.carthageBuildPath
    }
}

extension ProjectSpec: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        let jsonDictionary = try ProjectSpec.filterJSON(jsonDictionary: jsonDictionary)
        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingGroups = jsonDictionary.json(atKeyPath: "settingGroups") ?? jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        let configurations: [String: String] = jsonDictionary.json(atKeyPath: "configurations") ?? [:]
        self.configurations = configurations.map { Configuration(name: $0, type: ConfigurationType(rawValue: $1)) }
        targets = try jsonDictionary.json(atKeyPath: "targets").sorted { $0.name < $1.name }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
        if jsonDictionary["options"] != nil {
            options = try jsonDictionary.json(atKeyPath: "options")
        } else {
            options = Options()
        }
    }

    static func filterJSON(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        return try Target.generateCrossPlaformTargets(jsonDictionary: jsonDictionary)
    }
}

extension ProjectSpec.Options: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
    }
}
