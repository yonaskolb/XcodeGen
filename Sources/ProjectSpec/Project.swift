import Foundation
import JSONUtilities
import PathKit
import Yams

public struct Project: BuildSettingsContainer {

    public var basePath: Path
    public var name: String
    public var targets: [Target] {
        didSet {
            targetsMap = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, $0) })
        }
    }

    public var aggregateTargets: [AggregateTarget] {
        didSet {
            aggregateTargetsMap = Dictionary(uniqueKeysWithValues: aggregateTargets.map { ($0.name, $0) })
        }
    }

    public var packages: [String: SwiftPackage]
    public var localPackages: [String]

    public var settings: Settings
    public var settingGroups: [String: Settings]
    public var configs: [Config]
    public var schemes: [Scheme]
    public var options: SpecOptions
    public var attributes: [String: Any]
    public var fileGroups: [String]
    public var configFiles: [String: String]
    public var include: [String] = []
    public var externalProjects: [ExternalProject] = [] {
        didSet {
            externalProjectsMap = Dictionary(uniqueKeysWithValues: externalProjects.map { ($0.name, $0) })
        }
    }

    private var targetsMap: [String: Target]
    private var aggregateTargetsMap: [String: AggregateTarget]
    private var externalProjectsMap: [String: ExternalProject]

    public init(
        basePath: Path = "",
        name: String,
        configs: [Config] = Config.defaultConfigs,
        targets: [Target] = [],
        aggregateTargets: [AggregateTarget] = [],
        settings: Settings = .empty,
        settingGroups: [String: Settings] = [:],
        schemes: [Scheme] = [],
        packages: [String: SwiftPackage] = [:],
        localPackages: [String] = [],
        options: SpecOptions = SpecOptions(),
        fileGroups: [String] = [],
        configFiles: [String: String] = [:],
        attributes: [String: Any] = [:],
        externalProjects: [ExternalProject] = []
    ) {
        self.basePath = basePath
        self.name = name
        self.targets = targets
        targetsMap = Dictionary(uniqueKeysWithValues: self.targets.map { ($0.name, $0) })
        self.aggregateTargets = aggregateTargets
        aggregateTargetsMap = Dictionary(uniqueKeysWithValues: self.aggregateTargets.map { ($0.name, $0) })
        self.configs = configs
        self.settings = settings
        self.settingGroups = settingGroups
        self.schemes = schemes
        self.packages = packages
        self.localPackages = localPackages
        self.options = options
        self.fileGroups = fileGroups
        self.configFiles = configFiles
        self.attributes = attributes
        self.externalProjects = externalProjects
        externalProjectsMap = Dictionary(uniqueKeysWithValues: self.externalProjects.map { ($0.name, $0) })
    }

    public func getExternalProject(_ projectName: String) -> ExternalProject? {
        return externalProjectsMap[projectName]
    }

    public func getTarget(_ targetName: String) -> Target? {
        return targetsMap[targetName]
    }

    public func getAggregateTarget(_ targetName: String) -> AggregateTarget? {
        return aggregateTargetsMap[targetName]
    }

    public func getProjectTarget(_ targetName: String) -> ProjectTarget? {
        return targetsMap[targetName] ?? aggregateTargetsMap[targetName]
    }

    public func getConfig(_ configName: String) -> Config? {
        return configs.first { $0.name == configName }
    }

    public var defaultProjectPath: Path {
        return basePath + "\(name).xcodeproj"
    }
}

extension Project: CustomDebugStringConvertible {

    public var debugDescription: String {
        var string = "Name: \(name)"
        let indent = "  "
        if !include.isEmpty {
            string += "\nInclude:\n\(indent)" + include.map { $0.description }.joined(separator: "\n\(indent)")
        }

        if !settingGroups.isEmpty {
            string += "\nSetting Groups:\n\(indent)" + settingGroups.keys
                .sorted()
                .joined(separator: "\n\(indent)")
        }

        if !targets.isEmpty {
            string += "\nTargets:\n\(indent)" + targets.map { $0.description }.joined(separator: "\n\(indent)")
        }
        if !aggregateTargets.isEmpty {
            string += "\nAggregate Targets:\n\(indent)" + aggregateTargets.map { $0.description }.joined(separator: "\n\(indent)")
        }
        if !schemes.isEmpty {
            let allSchemes = targets.filter { $0.scheme != nil }.map { $0.name } + schemes.map { $0.name }
            string += "\nSchemes:\n\(indent)" + allSchemes.joined(separator: "\n\(indent)")
        }

        return string
    }
}

extension Project: Equatable {

    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
            lhs.aggregateTargets == rhs.aggregateTargets &&
            lhs.settings == rhs.settings &&
            lhs.settingGroups == rhs.settingGroups &&
            lhs.configs == rhs.configs &&
            lhs.schemes == rhs.schemes &&
            lhs.fileGroups == rhs.fileGroups &&
            lhs.configFiles == rhs.configFiles &&
            lhs.options == rhs.options &&
            lhs.packages == rhs.packages &&
            lhs.localPackages == rhs.localPackages &&
            NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

extension Project {

    public init(path: Path) throws {
        let spec = try SpecFile(path: path)
        try self.init(spec: spec)
    }

    public init(spec: SpecFile) throws {
        try self.init(basePath: spec.basePath, jsonDictionary: spec.resolvedDictionary())
    }

    public init(basePath: Path = "", jsonDictionary: JSONDictionary) throws {
        self.basePath = basePath

        let jsonDictionary = Project.resolveProject(jsonDictionary: jsonDictionary)

        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingGroups = jsonDictionary.json(atKeyPath: "settingGroups")
            ?? jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        let configs: [String: String] = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        self.configs = configs.isEmpty ? Config.defaultConfigs :
            configs.map { Config(name: $0, type: ConfigType(rawValue: $1)) }.sorted { $0.name < $1.name }
        targets = try jsonDictionary.json(atKeyPath: "targets").sorted { $0.name < $1.name }
        aggregateTargets = try jsonDictionary.json(atKeyPath: "aggregateTargets").sorted { $0.name < $1.name }
        externalProjects = try jsonDictionary.json(atKeyPath: "externalProjects").sorted { $0.name < $1.name }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        fileGroups = jsonDictionary.json(atKeyPath: "fileGroups") ?? []
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
        include = jsonDictionary.json(atKeyPath: "include") ?? []
        if jsonDictionary["packages"] != nil {
            packages = try jsonDictionary.json(atKeyPath: "packages", invalidItemBehaviour: .fail)
        } else {
            packages = [:]
        }
        localPackages = jsonDictionary.json(atKeyPath: "localPackages") ?? []
        if jsonDictionary["options"] != nil {
            options = try jsonDictionary.json(atKeyPath: "options")
        } else {
            options = SpecOptions()
        }
        targetsMap = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, $0) })
        aggregateTargetsMap = Dictionary(uniqueKeysWithValues: aggregateTargets.map { ($0.name, $0) })
        externalProjectsMap = Dictionary(uniqueKeysWithValues: externalProjects.map { ($0.name, $0) })
    }

    static func resolveProject(jsonDictionary: JSONDictionary) -> JSONDictionary {
        var jsonDictionary = jsonDictionary

        // resolve multiple times so that we support both multi-platform templates,
        // as well as platform specific templates in multi-platform targets
        jsonDictionary = Target.resolveMultiplatformTargets(jsonDictionary: jsonDictionary)
        jsonDictionary = Target.resolveTargetTemplates(jsonDictionary: jsonDictionary)
        jsonDictionary = Scheme.resolveSchemeTemplates(jsonDictionary: jsonDictionary)
        jsonDictionary = Target.resolveMultiplatformTargets(jsonDictionary: jsonDictionary)

        return jsonDictionary
    }
}

extension Project: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .string("configFiles"),
            .string("localPackages"),
            .object("options", SpecOptions.pathProperties),
            .object("targets", Target.pathProperties),
            .object("targetTemplates", Target.pathProperties),
            .object("aggregateTargets", AggregateTarget.pathProperties),
        ]
    }
}

extension Project {

    public var allFiles: [Path] {
        var files: [Path] = []
        files.append(contentsOf: configFilePaths)
        for fileGroup in fileGroups {
            let fileGroupPath = basePath + fileGroup
            let fileGroupChildren = (try? fileGroupPath.recursiveChildren()) ?? []
            files.append(contentsOf: fileGroupChildren)
            files.append(fileGroupPath)
        }

        for target in aggregateTargets {
            files.append(contentsOf: target.configFilePaths)
        }

        for target in targets {
            files.append(contentsOf: target.configFilePaths)
            for source in target.sources {
                let sourcePath = basePath + source.path
                let sourceChildren = (try? sourcePath.recursiveChildren()) ?? []
                files.append(contentsOf: sourceChildren)
                files.append(sourcePath)
            }
        }
        return files
    }
}

extension BuildSettingsContainer {

    fileprivate var configFilePaths: [Path] {
        return configFiles.values.map { Path($0) }
    }
}

extension Project: JSONEncodable {
    public func toJSONValue() -> Any {
        return toJSONDictionary()
    }

    public func toJSONDictionary() -> JSONDictionary {
        let targetPairs = targets.map { ($0.name, $0.toJSONValue()) }
        let configsPairs = configs.map { ($0.name, $0.type?.rawValue) }
        let aggregateTargetsPairs = aggregateTargets.map { ($0.name, $0.toJSONValue()) }
        let schemesPairs = schemes.map { ($0.name, $0.toJSONValue()) }
        let externalProjectsPairs = externalProjects.map { ($0.name, $0.toJSONValue()) }

        var dictionary: JSONDictionary = [:]
        dictionary["name"] = name
        dictionary["options"] = options.toJSONValue()
        dictionary["settings"] = settings.toJSONValue()
        dictionary["fileGroups"] = fileGroups
        dictionary["configFiles"] = configFiles
        dictionary["include"] = include
        dictionary["attributes"] = attributes
        dictionary["packages"] = packages.mapValues { $0.toJSONValue() }
        dictionary["localPackages"] = localPackages
        dictionary["targets"] = Dictionary(uniqueKeysWithValues: targetPairs)
        dictionary["configs"] = Dictionary(uniqueKeysWithValues: configsPairs)
        dictionary["aggregateTargets"] = Dictionary(uniqueKeysWithValues: aggregateTargetsPairs)
        dictionary["schemes"] = Dictionary(uniqueKeysWithValues: schemesPairs)
        dictionary["settingGroups"] = settingGroups.mapValues { $0.toJSONValue() }
        dictionary["externalProjects"] = externalProjectsPairs

        return dictionary
    }
}


public struct ExternalProject {
    public let name: String
    public let path: String

    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

extension ExternalProject: NamedJSONDictionaryConvertible {
    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = name
        self.path = try jsonDictionary.json(atKeyPath: "path")
    }
}

extension ExternalProject: JSONEncodable {
    public func toJSONValue() -> Any {
        return [
            "path": path,
        ]
    }
}
