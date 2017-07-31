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
    public var settings: Settings
    public var sources: [String]
    public var sourceExludes: [String]
    public var dependencies: [Dependency]
    public var prebuildScripts: [String]
    public var postbuildScripts: [String]
    public var configFiles: [String: String]
    public var generateSchemes: [String]

    public var filename: String {
        var name = self.name
        if let fileExtension = type.fileExtension {
            name += ".\(fileExtension)"
        }
        return name
    }

    public init(name: String, type: PBXProductType, platform: Platform, settings: Settings = .empty, configFiles: [String: String] = [:], sources: [String] = [], sourceExludes: [String] = [], dependencies: [Dependency] = [], prebuildScripts: [String] = [], postbuildScripts: [String] = [], generateSchemes: [String] = []) {
        self.name = name
        self.type = type
        self.platform = platform
        self.settings = settings
        self.configFiles = configFiles
        self.sources = sources
        self.sourceExludes = sourceExludes
        self.dependencies = dependencies
        self.prebuildScripts = prebuildScripts
        self.postbuildScripts = postbuildScripts
        self.generateSchemes = generateSchemes
    }
}

extension Target: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        name = try jsonDictionary.json(atKeyPath: "name")
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = PBXProductType(string: typeString) {
            self.type = type
        } else {
            throw ProjectSpecError.unknownTargetType(typeString)
        }
        let platformString: String = try jsonDictionary.json(atKeyPath: "platform")
        if let platform = Platform(rawValue: platformString) {
            self.platform = platform
        } else {
            throw ProjectSpecError.unknownTargetPlatform(platformString)
        }
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        if let source: String = jsonDictionary.json(atKeyPath: "sources") {
            sources = [source]
        } else {
            sources = jsonDictionary.json(atKeyPath: "sources") ?? []
        }
        sourceExludes = jsonDictionary.json(atKeyPath: "sourceExludes") ?? []
        if jsonDictionary["dependencies"] == nil {
            dependencies = []
        } else {
            dependencies = try jsonDictionary.json(atKeyPath: "dependencies", invalidItemBehaviour: .fail)
        }
        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
        generateSchemes = jsonDictionary.json(atKeyPath: "generateSchemes") ?? []
    }
}

public enum Dependency: Equatable {

    case target(String)
    case framework(String)
    case carthage(String)

    public static func ==(lhs: Dependency, rhs: Dependency) -> Bool {
        switch (lhs, rhs) {
        case let (.target(lhs), .target(rhs)): return lhs == rhs
        case let (.framework(lhs), .framework(rhs)): return lhs == rhs
        case let (.carthage(lhs), .carthage(rhs)): return lhs == rhs
        default: return false
        }
    }
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
            throw ProjectSpecError.invalidDependency(jsonDictionary)
        }
    }
}
