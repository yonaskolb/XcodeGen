//
//  Target.swift
//  XcodeGen
//
//  Created by Yonas Kolb on 20/7/17.
//
//

import Foundation
import xcodeproj
import JSONUtilities

public struct Target {
    public var name: String
    public var type: PBXProductType
    public var platform: Platform
    public var buildSettings: TargetBuildSettings?
    public var sources: [String]
    public var sourceExludes: [String]
    public var dependencies: [Dependency]
    public var prebuildScripts: [String]
    public var postbuildScripts: [String]
    public var configs: [String: String]

    public var filename: String {
        var name = self.name
        if let fileExtension = type.fileExtension {
            name += ".\(fileExtension)"
        }
        return name
    }

    public init(name: String, type: PBXProductType, platform: Platform, buildSettings: TargetBuildSettings?, configs: [String: String] = [:], sources: [String] = [], sourceExludes: [String] = [], dependencies: [Dependency] = [], prebuildScripts: [String] = [], postbuildScripts: [String]) {
        self.name = name
        self.type = type
        self.platform = platform
        self.buildSettings = buildSettings
        self.configs = configs
        self.sources = sources
        self.sourceExludes = sourceExludes
        self.dependencies = dependencies
        self.prebuildScripts = prebuildScripts
        self.postbuildScripts = postbuildScripts
    }
}

extension Target: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = PBXProductType(string: typeString) {
            self.type = type
        } else {
            throw SpecError.unknownTargetType(typeString)
        }
        let platformString: String = try jsonDictionary.json(atKeyPath: "platform")
        if let platform = Platform(rawValue: platformString)  {
            self.platform = platform
        } else {
            throw SpecError.unknownTargetPlatform(platformString)
        }
        buildSettings = jsonDictionary.json(atKeyPath: "buildSettings")
        configs = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        if let source: String = jsonDictionary.json(atKeyPath: "sources") {
            sources = [source]
        } else {
            sources = jsonDictionary.json(atKeyPath: "sources") ?? []
        }
        sourceExludes = jsonDictionary.json(atKeyPath: "sourceExludes") ?? []
        dependencies = jsonDictionary.json(atKeyPath: "dependencies") ?? []
        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
    }
}

public enum Dependency {

    case target(String)
    case framework(String)
    case carthage(String)

}

extension Dependency: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let target: String = jsonDictionary.json(atKeyPath: "target") {
            self = .target(target)
        } else if let framework: String = jsonDictionary.json(atKeyPath: "framework") {
            self = .framework(framework)
        } else if let carthage: String = jsonDictionary.json(atKeyPath: "carthage") {
            self = .carthage(carthage)
        } else {
            throw SpecError.invalidDependency(jsonDictionary)
        }
    }
}

