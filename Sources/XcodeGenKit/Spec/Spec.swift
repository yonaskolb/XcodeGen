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
    public var settingGroups: [BuildSettingGroup]
    public var configs: [Config]
    public var schemes: [Scheme]
    public var configVariants: [String]
    
    public init(path: Path, name: String, targets: [Target] = [], configs: [Config] = [], configVariants: [String] = [], settingGroups: [BuildSettingGroup] = [], schemes: [Scheme] = []) {
        self.path = path
        self.name = name
        self.targets = targets
        self.configs = configs
        self.configVariants = configVariants
        self.settingGroups = settingGroups
        self.schemes = schemes
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
        settingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        configs = try jsonDictionary.json(atKeyPath: "configs")
        if jsonDictionary["targets"] == nil {
            targets = []
        } else {
            targets = try jsonDictionary.json(atKeyPath: "targets", invalidItemBehaviour: .fail)
        }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        configVariants = jsonDictionary.json(atKeyPath: "configVariants") ?? []
    }
}
