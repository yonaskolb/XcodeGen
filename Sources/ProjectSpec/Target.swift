import Foundation
import JSONUtilities
import xcodeproj

public struct LegacyTarget: Equatable {
    public var toolPath: String
    public var arguments: String?
    public var passSettings: Bool
    public var workingDirectory: String?

    public init(
        toolPath: String,
        passSettings: Bool = false,
        arguments: String? = nil,
        workingDirectory: String? = nil
    ) {
        self.toolPath = toolPath
        self.arguments = arguments
        self.passSettings = passSettings
        self.workingDirectory = workingDirectory
    }
}

public struct Target: ProjectTarget {
    public var name: String
    public var type: PBXProductType
    public var platform: Platform
    public var settings: Settings
    public var sources: [TargetSource]
    public var dependencies: [Dependency]
    public var info: Plist?
    public var entitlements: Plist?
    public var transitivelyLinkDependencies: Bool?
    public var directlyEmbedCarthageDependencies: Bool?
    public var requiresObjCLinking: Bool?
    public var preBuildScripts: [BuildScript]
    public var postCompileScripts: [BuildScript]
    public var postBuildScripts: [BuildScript]
    public var buildRules: [BuildRule]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?
    public var legacy: LegacyTarget?
    public var deploymentTarget: Version?
    public var attributes: [String: Any]
    public var productName: String

    public var isLegacy: Bool {
        return legacy != nil
    }

    public var filename: String {
        var filename = productName
        if let fileExtension = type.fileExtension {
            filename += ".\(fileExtension)"
        }
        return filename
    }

    public init(
        name: String,
        type: PBXProductType,
        platform: Platform,
        productName: String? = nil,
        deploymentTarget: Version? = nil,
        settings: Settings = .empty,
        configFiles: [String: String] = [:],
        sources: [TargetSource] = [],
        dependencies: [Dependency] = [],
        info: Plist? = nil,
        entitlements: Plist? = nil,
        transitivelyLinkDependencies: Bool? = nil,
        directlyEmbedCarthageDependencies: Bool? = nil,
        requiresObjCLinking: Bool? = nil,
        preBuildScripts: [BuildScript] = [],
        postCompileScripts: [BuildScript] = [],
        postBuildScripts: [BuildScript] = [],
        buildRules: [BuildRule] = [],
        scheme: TargetScheme? = nil,
        legacy: LegacyTarget? = nil,
        attributes: [String: Any] = [:]
    ) {
        self.name = name
        self.type = type
        self.platform = platform
        self.deploymentTarget = deploymentTarget
        self.productName = productName ?? name
        self.settings = settings
        self.configFiles = configFiles
        self.sources = sources
        self.dependencies = dependencies
        self.info = info
        self.entitlements = entitlements
        self.transitivelyLinkDependencies = transitivelyLinkDependencies
        self.directlyEmbedCarthageDependencies = directlyEmbedCarthageDependencies
        self.requiresObjCLinking = requiresObjCLinking
        self.preBuildScripts = preBuildScripts
        self.postCompileScripts = postCompileScripts
        self.postBuildScripts = postBuildScripts
        self.buildRules = buildRules
        self.scheme = scheme
        self.legacy = legacy
        self.attributes = attributes
    }
}

extension Target: CustomStringConvertible {

    public var description: String {
        return "\(name): \(platform.rawValue) \(type)"
    }
}

extension Target: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .dictionary([
                .string("sources"),
                .object("sources", TargetSource.pathProperties),
                .string("configFiles"),
                .object("dependencies", Dependency.pathProperties),
                .object("info", Plist.pathProperties),
                .object("entitlements", Plist.pathProperties),
                .object("preBuildScripts", BuildScript.pathProperties),
                .object("prebuildScripts", BuildScript.pathProperties),
                .object("postCompileScripts", BuildScript.pathProperties),
                .object("postBuildScripts", BuildScript.pathProperties),
            ]),
        ]
    }
}

extension Target {

    static func resolveTargetTemplates(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        guard var targetsDictionary: [String: JSONDictionary] = jsonDictionary["targets"] as? [String: JSONDictionary] else {
            return jsonDictionary
        }

        let targetTemplatesDictionary: [String: JSONDictionary] = jsonDictionary["targetTemplates"] as? [String: JSONDictionary] ?? [:]

        for (targetName, var target) in targetsDictionary {

            if let templates = target["templates"] as? [String] {
                var mergedDictionary: JSONDictionary = [:]
                for template in templates {
                    if let templateDictionary = targetTemplatesDictionary[template] {
                        mergedDictionary = templateDictionary.merged(onto: mergedDictionary)
                    }
                }
                target = target.merged(onto: mergedDictionary)
                target = target.replaceString("$target_name", with: targetName)
            }
            targetsDictionary[targetName] = target
        }

        var jsonDictionary = jsonDictionary
        jsonDictionary["targets"] = targetsDictionary
        return jsonDictionary
    }

    static func resolveMultiplatformTargets(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        guard let targetsDictionary: [String: JSONDictionary] = jsonDictionary["targets"] as? [String: JSONDictionary] else {
            return jsonDictionary
        }

        var crossPlatformTargets: [String: JSONDictionary] = [:]

        for (targetName, target) in targetsDictionary {

            if let platforms = target["platform"] as? [String] {

                for platform in platforms {
                    var platformTarget = target

                    platformTarget = platformTarget.replaceString("$platform", with: platform)

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
                    platformTarget["productName"] = targetName
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

    public static func == (lhs: Target, rhs: Target) -> Bool {
        return lhs.name == rhs.name &&
            lhs.type == rhs.type &&
            lhs.platform == rhs.platform &&
            lhs.deploymentTarget == rhs.deploymentTarget &&
            lhs.transitivelyLinkDependencies == rhs.transitivelyLinkDependencies &&
            lhs.requiresObjCLinking == rhs.requiresObjCLinking &&
            lhs.directlyEmbedCarthageDependencies == rhs.directlyEmbedCarthageDependencies &&
            lhs.settings == rhs.settings &&
            lhs.configFiles == rhs.configFiles &&
            lhs.sources == rhs.sources &&
            lhs.info == rhs.info &&
            lhs.entitlements == rhs.entitlements &&
            lhs.dependencies == rhs.dependencies &&
            lhs.preBuildScripts == rhs.preBuildScripts &&
            lhs.postCompileScripts == rhs.postCompileScripts &&
            lhs.postBuildScripts == rhs.postBuildScripts &&
            lhs.buildRules == rhs.buildRules &&
            lhs.scheme == rhs.scheme &&
            lhs.legacy == rhs.legacy &&
            NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

extension LegacyTarget: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        toolPath = try jsonDictionary.json(atKeyPath: "toolPath")
        arguments = jsonDictionary.json(atKeyPath: "arguments")
        passSettings = jsonDictionary.json(atKeyPath: "passSettings") ?? false
        workingDirectory = jsonDictionary.json(atKeyPath: "workingDirectory")
    }
}

extension Target: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        let resolvedName: String = jsonDictionary.json(atKeyPath: "name") ?? name
        self.name = resolvedName
        productName = jsonDictionary.json(atKeyPath: "productName") ?? resolvedName
        let typeString: String = try jsonDictionary.json(atKeyPath: "type")
        if let type = PBXProductType(string: typeString) {
            self.type = type
        } else {
            throw SpecParsingError.unknownTargetType(typeString)
        }
        let platformString: String = try jsonDictionary.json(atKeyPath: "platform")
        if let platform = Platform(rawValue: platformString) {
            self.platform = platform
        } else {
            throw SpecParsingError.unknownTargetPlatform(platformString)
        }

        if let string: String = jsonDictionary.json(atKeyPath: "deploymentTarget") {
            deploymentTarget = try Version(string)
        } else if let double: Double = jsonDictionary.json(atKeyPath: "deploymentTarget") {
            deploymentTarget = try Version(double)
        } else {
            deploymentTarget = nil
        }

        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        if let source: String = jsonDictionary.json(atKeyPath: "sources") {
            sources = [TargetSource(path: source)]
        } else if let array = jsonDictionary["sources"] as? [Any] {
            sources = try array.compactMap { source in
                if let string = source as? String {
                    return TargetSource(path: string)
                } else if let dictionary = source as? [String: Any] {
                    return try TargetSource(jsonDictionary: dictionary)
                } else {
                    return nil
                }
            }
        } else {
            sources = []
        }
        if jsonDictionary["dependencies"] == nil {
            dependencies = []
        } else {
            dependencies = try jsonDictionary.json(atKeyPath: "dependencies", invalidItemBehaviour: .fail)
        }

        if jsonDictionary["info"] != nil {
            info = try jsonDictionary.json(atKeyPath: "info") as Plist
        }
        if jsonDictionary["entitlements"] != nil {
            entitlements = try jsonDictionary.json(atKeyPath: "entitlements") as Plist
        }

        transitivelyLinkDependencies = jsonDictionary.json(atKeyPath: "transitivelyLinkDependencies")
        directlyEmbedCarthageDependencies = jsonDictionary.json(atKeyPath: "directlyEmbedCarthageDependencies")
        requiresObjCLinking = jsonDictionary.json(atKeyPath: "requiresObjCLinking")

        preBuildScripts = jsonDictionary.json(atKeyPath: "preBuildScripts") ?? jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postCompileScripts = jsonDictionary.json(atKeyPath: "postCompileScripts") ?? []
        postBuildScripts = jsonDictionary.json(atKeyPath: "postBuildScripts") ?? jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
        buildRules = jsonDictionary.json(atKeyPath: "buildRules") ?? []
        scheme = jsonDictionary.json(atKeyPath: "scheme")
        legacy = jsonDictionary.json(atKeyPath: "legacy")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
    }
}
