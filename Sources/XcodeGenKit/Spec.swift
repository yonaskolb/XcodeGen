//
//  Spec.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 19/5/17.
//
//

import Foundation


import JSONUtilities
import PathKit
import Yams

extension Spec {

    public init(path: Path) throws {
        var url = URL(string: path.string)!
        if url.scheme == nil {
            url = URL(fileURLWithPath: path.string)
        }

        let data = try Data(contentsOf: url)
        let string = String(data: data, encoding: .utf8)!

        try self.init(path: path, string: string)
    }

    public init(path: Path, string: String) throws {
        let yaml = try Yams.load(yaml: string)
        let json = yaml as! JSONDictionary

        try self.init(path: path, jsonDictionary: json)
    }

    public init(path: Path, jsonDictionary: JSONDictionary) throws {
        self.path = path
        settingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        configs = try jsonDictionary.json(atKeyPath: "configs")
        targets = try jsonDictionary.json(atKeyPath: "targets")
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
    }
}


public struct Spec {

    public var settingGroups: [BuildSettingGroup]
    public var configs: [Config]
    public var targets: [TargetSpec]
    public var schemes: [SchemeSpec]
    public var path: Path
}

public struct TargetSpec {
    public var name: String
    public var type: String
    public var localizedSource: String?
    public var sources: [String]
    public var sourceExludes: [String]
    public var dependancies: [Dependancy]
    public var prebuildScripts: [String]
    public var postbuildScripts: [String]
}

extension TargetSpec: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        type = try jsonDictionary.json(atKeyPath: "type")
        sources = jsonDictionary.json(atKeyPath: "sources") ?? []
        sourceExludes = jsonDictionary.json(atKeyPath: "sourceExludes") ?? []
        dependancies = jsonDictionary.json(atKeyPath: "dependancies") ?? []
        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
    }
}


public struct Dependancy {

    public var path: String
    public var type: DependancyType

    public enum DependancyType: String {
        case target
        case system
    }
}

extension Dependancy: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        path = try jsonDictionary.json(atKeyPath: "path")
        type = try jsonDictionary.json(atKeyPath: "type")
    }
}

public struct Config {
    public var name: String
    public var buildSettingGroups: [BuildSettingGroup]
    public var settings: [String: String]
}

extension Config: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        buildSettingGroups = try jsonDictionary.json(atKeyPath: "settingGroups")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? [:]
    }
}

public struct BuildSettingGroup {
    public var name: String
    public var buildSettings: [String: String]
}

extension BuildSettingGroup: NamedJSONObjectConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        buildSettings = [:]
        for (key, value) in jsonDictionary {
            buildSettings[key] = String(describing: value)
        }
    }
}
