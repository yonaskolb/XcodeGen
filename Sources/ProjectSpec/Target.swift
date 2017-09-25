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
    public var prebuildScripts: [BuildScript]
    public var postbuildScripts: [BuildScript]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?

    public var filename: String {
        var name = self.name
        if let fileExtension = type.fileExtension {
            name += ".\(fileExtension)"
        }
        return name
    }

    public init(name: String, type: PBXProductType, platform: Platform, settings: Settings = .empty, configFiles: [String: String] = [:], sources: [String] = [], sourceExludes: [String] = [], dependencies: [Dependency] = [], prebuildScripts: [BuildScript] = [], postbuildScripts: [BuildScript] = [], scheme: TargetScheme? = nil) {
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
        self.scheme = scheme
    }
}

extension Target: CustomStringConvertible {

    public var description: String {
        return "\(platform.emoji) \(type): \(name)"
    }
}

extension Target {

    static func generateCrossPlaformTargets(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        guard let targetsDictionary: [String: JSONDictionary] = jsonDictionary["targets"] as? [String: JSONDictionary] else {
            return jsonDictionary
        }

        let platformReplacement = "$platform"
        var crossPlatformTargets: [String: JSONDictionary] = [:]

        for (targetName, target) in targetsDictionary {

            if let platforms = target["platform"] as? [String] {

                for platform in platforms {
                    var platformTarget = target

                    func replacePlatform(_ dictionary: JSONDictionary) -> JSONDictionary {
                        var replaced = dictionary
                        for (key, value) in dictionary {
                            switch value {
                            case let dictionary as JSONDictionary:
                                replaced[key] = replacePlatform(dictionary)
                            case let string as String:
                                replaced[key] = string.replacingOccurrences(of: platformReplacement, with: platform)
                            case let array as [JSONDictionary]:
                                replaced[key] = array.map(replacePlatform)
                            case let array as [String]:
                                replaced[key] = array.map { $0.replacingOccurrences(of: platformReplacement, with: platform) }
                            default: break
                            }
                        }
                        return replaced
                    }

                    platformTarget = replacePlatform(platformTarget)

                    platformTarget["platform"] = platform
                    let platformSuffix = platformTarget["platformSuffix"] as? String ?? "_\(platform)"
                    let platformPrefix = platformTarget["platformPrefix"] as? String ?? ""
                    let newTargetName = platformPrefix + targetName + platformSuffix

                    var settings = platformTarget["settings"] as? JSONDictionary ?? [:]
                    if settings["configs"] != nil || settings["groups"] != nil || settings["base"] != nil {
                        var base = settings["base"] as? JSONDictionary ?? [:]
                        if base["PRODUCT_NAME"] == nil {
                            base["PRODUCT_NAME"] = targetName
                        }
                        settings["base"] = base
                    } else {
                        if settings["PRODUCT_NAME"] == nil {
                            settings["PRODUCT_NAME"] = targetName
                        }
                    }
                    platformTarget["settings"] = settings
                    crossPlatformTargets[newTargetName] = platformTarget
                }
            } else {
                crossPlatformTargets[targetName] = target
            }
        }
        var merged = jsonDictionary
        merged["targets"] = crossPlatformTargets
        return merged
    }
}

extension Target: Equatable {

    public static func ==(lhs: Target, rhs: Target) -> Bool {
        return lhs.name == rhs.name &&
            lhs.type == rhs.type &&
            lhs.platform == rhs.platform &&
            lhs.settings == rhs.settings &&
            lhs.configFiles == rhs.configFiles &&
            lhs.sources == rhs.sources &&
            lhs.sourceExludes == rhs.sourceExludes &&
            lhs.dependencies == rhs.dependencies &&
            lhs.prebuildScripts == rhs.prebuildScripts &&
            lhs.postbuildScripts == rhs.postbuildScripts &&
            lhs.scheme == rhs.scheme
    }
}

public struct TargetScheme {
    public let testTargets: [String]
    public let configVariants: [String]

    public init(testTargets: [String] = [], configVariants: [String] = []) {
        self.testTargets = testTargets
        self.configVariants = configVariants
    }
}

extension TargetScheme: Equatable {

    public static func ==(lhs: TargetScheme, rhs: TargetScheme) -> Bool {
        return lhs.testTargets == rhs.testTargets &&
            lhs.configVariants == rhs.configVariants
    }
}

extension TargetScheme: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        testTargets = jsonDictionary.json(atKeyPath: "testTargets") ?? []
        configVariants = jsonDictionary.json(atKeyPath: "configVariants") ?? []
    }
}

extension Target: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = jsonDictionary.json(atKeyPath: "name") ?? name
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
        scheme = jsonDictionary.json(atKeyPath: "scheme")
    }
}

public struct Dependency: Equatable {

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool = true
    public var removeHeaders: Bool = true

    public init(type: DependencyType, reference: String, embed: Bool? = nil) {
        self.type = type
        self.reference = reference
        self.embed = embed
    }

    public enum DependencyType {
        case target
        case framework
        case carthage
    }

    public static func ==(lhs: Dependency, rhs: Dependency) -> Bool {
        return lhs.reference == rhs.reference &&
            lhs.type == rhs.type &&
            lhs.codeSign == rhs.codeSign &&
            lhs.removeHeaders == rhs.removeHeaders &&
            lhs.embed == rhs.embed
    }

    public var buildSettings: [String: Any] {
        var attributes: [String] = []
        if codeSign {
            attributes.append("CodeSignOnCopy")
        }
        if removeHeaders {
            attributes.append("RemoveHeadersOnCopy")
        }
        return ["ATTRIBUTES": attributes]
    }
}

extension Dependency: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let target: String = jsonDictionary.json(atKeyPath: "target") {
            type = .target
            reference = target
        } else if let framework: String = jsonDictionary.json(atKeyPath: "framework") {
            type = .framework
            reference = framework
        } else if let carthage: String = jsonDictionary.json(atKeyPath: "carthage") {
            type = .carthage
            reference = carthage
        } else {
            throw ProjectSpecError.invalidDependency(jsonDictionary)
        }

        embed = jsonDictionary.json(atKeyPath: "embed")

        if let bool: Bool = jsonDictionary.json(atKeyPath: "codeSign") {
            codeSign = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "removeHeaders") {
            removeHeaders = bool
        }
    }
}
