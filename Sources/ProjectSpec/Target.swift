import Foundation
import JSONUtilities
import xcproj

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

public struct Target {
    public var name: String
    public var type: PBXProductType
    public var platform: Platform
    public var settings: Settings
    public var sources: [TargetSource]
    public var dependencies: [Dependency]
    public var transientlyLinkDependencies: Bool?
    public var prebuildScripts: [BuildScript]
    public var postbuildScripts: [BuildScript]
    public var buildRules: [BuildRule]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?
    public var legacy: LegacyTarget?
    public var deploymentTarget: Version?
    public var attributes: [String: Any]
    internal var productName: String?

    public var isLegacy: Bool {
        return legacy != nil
    }

    public var filename: String {
        var filename = productName ?? name
        if let fileExtension = type.fileExtension {
            filename += ".\(fileExtension)"
        }
        return filename
    }

    public init(
        name: String,
        type: PBXProductType,
        platform: Platform,
        deploymentTarget: Version? = nil,
        settings: Settings = .empty,
        configFiles: [String: String] = [:],
        sources: [TargetSource] = [],
        dependencies: [Dependency] = [],
        transientlyLinkDependencies: Bool? = nil,
        prebuildScripts: [BuildScript] = [],
        postbuildScripts: [BuildScript] = [],
        buildRules: [BuildRule] = [],
        scheme: TargetScheme? = nil,
        legacy: LegacyTarget? = nil,
        attributes: [String: Any] = [:]
    ) {
        self.name = name
        self.type = type
        self.platform = platform
        self.deploymentTarget = deploymentTarget
        self.settings = settings
        self.configFiles = configFiles
        self.sources = sources
        self.dependencies = dependencies
        self.transientlyLinkDependencies = transientlyLinkDependencies
        self.prebuildScripts = prebuildScripts
        self.postbuildScripts = postbuildScripts
        self.buildRules = buildRules
        self.scheme = scheme
        self.legacy = legacy
        self.attributes = attributes
    }
}

extension Target: CustomStringConvertible {

    public var description: String {
        return "\(platform.emoji)  \(name): \(type)"
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
            lhs.transientlyLinkDependencies == rhs.transientlyLinkDependencies &&
            lhs.settings == rhs.settings &&
            lhs.configFiles == rhs.configFiles &&
            lhs.sources == rhs.sources &&
            lhs.dependencies == rhs.dependencies &&
            lhs.prebuildScripts == rhs.prebuildScripts &&
            lhs.postbuildScripts == rhs.postbuildScripts &&
            lhs.buildRules == rhs.buildRules &&
            lhs.scheme == rhs.scheme &&
            lhs.legacy == rhs.legacy &&
            NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

public struct TargetScheme: Equatable {
    public var testTargets: [String]
    public var configVariants: [String]
    public var gatherCoverageData: Bool
    public var commandLineArguments: [String: Bool]
    public var environmentVariables: [XCScheme.EnvironmentVariable]
    public var preActions: [Scheme.ExecutionAction]
    public var postActions: [Scheme.ExecutionAction]

    public init(
        testTargets: [String] = [],
        configVariants: [String] = [],
        gatherCoverageData: Bool = false,
        commandLineArguments: [String: Bool] = [:],
        environmentVariables: [XCScheme.EnvironmentVariable] = [],
        preActions: [Scheme.ExecutionAction] = [],
        postActions: [Scheme.ExecutionAction] = []
    ) {
        self.testTargets = testTargets
        self.configVariants = configVariants
        self.gatherCoverageData = gatherCoverageData
        self.commandLineArguments = commandLineArguments
        self.environmentVariables = environmentVariables
        self.preActions = preActions
        self.postActions = postActions
    }
}

extension TargetScheme: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        testTargets = jsonDictionary.json(atKeyPath: "testTargets") ?? []
        configVariants = jsonDictionary.json(atKeyPath: "configVariants") ?? []
        gatherCoverageData = jsonDictionary.json(atKeyPath: "gatherCoverageData") ?? false
        commandLineArguments = jsonDictionary.json(atKeyPath: "commandLineArguments") ?? [:]
        environmentVariables = try XCScheme.EnvironmentVariable.parseAll(jsonDictionary: jsonDictionary)
        preActions = jsonDictionary.json(atKeyPath: "preActions") ?? []
        postActions = jsonDictionary.json(atKeyPath: "postActions") ?? []
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
        self.name = jsonDictionary.json(atKeyPath: "name") ?? name
        productName = jsonDictionary.json(atKeyPath: "productName")
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
        transientlyLinkDependencies = jsonDictionary.json(atKeyPath: "transientlyLinkDependencies")

        prebuildScripts = jsonDictionary.json(atKeyPath: "prebuildScripts") ?? []
        postbuildScripts = jsonDictionary.json(atKeyPath: "postbuildScripts") ?? []
        buildRules = jsonDictionary.json(atKeyPath: "buildRules") ?? []
        scheme = jsonDictionary.json(atKeyPath: "scheme")
        legacy = jsonDictionary.json(atKeyPath: "legacy")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
    }
}
