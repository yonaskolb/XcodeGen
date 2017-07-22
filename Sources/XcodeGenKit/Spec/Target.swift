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

    public var filename: String {
        var name = self.name
        if let fileExtension = type.fileExtension {
            name += ".\(fileExtension)"
        }
        return name
    }

    public init(name: String, type: PBXProductType, platform: Platform, buildSettings: TargetBuildSettings?, sources: [String] = [], sourceExludes: [String] = [], dependencies: [Dependency] = [], prebuildScripts: [String] = [], postbuildScripts: [String]) {
        self.name = name
        self.type = type
        self.platform = platform
        self.buildSettings = buildSettings
        self.sources = sources
        self.sourceExludes = sourceExludes
        self.dependencies = dependencies
        self.prebuildScripts = prebuildScripts
        self.postbuildScripts = postbuildScripts
    }
}

extension Target: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = PBXProductType(rawValue: typeString) {
            self.type = type
        } else {
            switch typeString {
            case "application": type = .application
            case "framework": type = .framework
            default: throw SpecError.unknownTargetType(typeString)
            }
        }
        platform = try jsonDictionary.json(atKeyPath: "platform")
        buildSettings = jsonDictionary.json(atKeyPath: "buildSettings")
        sources = jsonDictionary.json(atKeyPath: "sources") ?? []
        sourceExludes = jsonDictionary.json(atKeyPath: "sourceExludes") ?? []
        dependencies = jsonDictionary.json(atKeyPath: "dependencies") ?? []
        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
    }
}

public struct Dependency {

    public var name: String
    public var type: DependancyType

    public enum DependancyType: String {
        case target
        case system
    }

    public init(name: String, type: DependancyType) {
        self.name = name
        self.type = type
    }
}

extension Dependency: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        type = try jsonDictionary.json(atKeyPath: "type")
    }
}

