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

extension Spec {

    public init(path: Path) throws {
        let string: String = try path.read()
        try self.init(path: path, string: string)
    }

    public init(path: Path, string: String) throws {
        let yaml = try Yams.load(yaml: string)
        let json = yaml as! JSONDictionary

        try self.init(path: path, jsonDictionary: json)
    }

    public init(path: Path, jsonDictionary: JSONDictionary) throws {
        self.path = path
        name = try jsonDictionary.json(atKeyPath: "name")
        settingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        configs = try jsonDictionary.json(atKeyPath: "configs")
        targets = try jsonDictionary.json(atKeyPath: "targets")
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
    }
}


public struct Spec {

    public var path: Path
    public var name: String
    public var targets: [Target]
    public var settingGroups: [BuildSettingGroup]
    public var configs: [Config]
    public var schemes: [Scheme]

    public init(path: Path, name: String, targets: [Target] = [], configs: [Config] = [], settingGroups: [BuildSettingGroup] = [], schemes: [Scheme] = []) {
        self.path = path
        self.name = name
        self.targets = targets
        self.configs = configs
        self.settingGroups = settingGroups
        self.schemes = schemes
    }
}
