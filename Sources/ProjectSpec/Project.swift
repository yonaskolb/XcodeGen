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

    public var settings: Settings
    public var settingGroups: [String: Settings]
    public var configs: [Config]
    public var schemes: [Scheme]
    public var options: SpecOptions
    public var attributes: [String: Any]
    public var fileGroups: [String]
    public var configFiles: [String: String]
    public var include: [String] = []

    private var targetsMap: [String: Target]
    private var aggregateTargetsMap: [String: AggregateTarget]

    public init(
        basePath: Path = "",
        name: String,
        configs: [Config] = Config.defaultConfigs,
        targets: [Target] = [],
        aggregateTargets: [AggregateTarget] = [],
        settings: Settings = .empty,
        settingGroups: [String: Settings] = [:],
        schemes: [Scheme] = [],
        options: SpecOptions = SpecOptions(),
        fileGroups: [String] = [],
        configFiles: [String: String] = [:],
        attributes: [String: Any] = [:]
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
        self.options = options
        self.fileGroups = fileGroups
        self.configFiles = configFiles
        self.attributes = attributes
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

        let jsonDictionary = try Project.resolveProject(jsonDictionary: jsonDictionary)

        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingGroups = jsonDictionary.json(atKeyPath: "settingGroups")
            ?? jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        let configs: [String: String] = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        self.configs = configs.isEmpty ? Config.defaultConfigs :
            configs.map { Config(name: $0, type: ConfigType(rawValue: $1)) }.sorted { $0.name < $1.name }
        targets = try jsonDictionary.json(atKeyPath: "targets").sorted { $0.name < $1.name }
        aggregateTargets = try jsonDictionary.json(atKeyPath: "aggregateTargets").sorted { $0.name < $1.name }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        fileGroups = jsonDictionary.json(atKeyPath: "fileGroups") ?? []
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
        include = jsonDictionary.json(atKeyPath: "include") ?? []
        if jsonDictionary["options"] != nil {
            options = try jsonDictionary.json(atKeyPath: "options")
        } else {
            options = SpecOptions()
        }
        targetsMap = Dictionary(uniqueKeysWithValues: targets.map { ($0.name, $0) })
        aggregateTargetsMap = Dictionary(uniqueKeysWithValues: aggregateTargets.map { ($0.name, $0) })
    }

    static func resolveProject(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        var jsonDictionary = jsonDictionary

        // resolve multiple times so that we support both multi-platform templates,
        // as well as platform specific templates in multi-platform targets
        jsonDictionary = try Target.resolveMultiplatformTargets(jsonDictionary: jsonDictionary)
        jsonDictionary = try Target.resolveTargetTemplates(jsonDictionary: jsonDictionary)
        jsonDictionary = try Target.resolveMultiplatformTargets(jsonDictionary: jsonDictionary)

        return jsonDictionary
    }
}

extension Project: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .string("configFiles"),
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
        var dict: JSONDictionary = [
            "name": name,
            "options": options.toJSONValue(),
        ]

        let settingsDict = settings.toJSONValue()
        if settingsDict.count > 0 {
            dict["settings"] = settingsDict
        }

        if fileGroups.count > 0 {
            dict["fileGroups"] = fileGroups
        }
        if configFiles.count > 0 {
            dict["configFiles"] = configFiles
        }
        if include.count > 0 {
            dict["include"] = include
        }
        if attributes.count > 0 {
            dict["attributes"] = attributes
        }

        let targetPairs = targets.map { ($0.name, $0.toJSONValue()) }
        if targetPairs.count > 0 {
            dict["targets"] = Dictionary(uniqueKeysWithValues: targetPairs)
        }

        let configsPairs = configs.map { ($0.name, $0.type?.rawValue) }
        if configsPairs.count > 0 {
            dict["configs"] = Dictionary(uniqueKeysWithValues: configsPairs)
        }

        let aggregateTargetsPairs = aggregateTargets.map { ($0.name, $0.toJSONValue()) }
        if aggregateTargetsPairs.count > 0 {
            dict["aggregateTargets"] = Dictionary(uniqueKeysWithValues: aggregateTargetsPairs)
        }

        let schemesPairs = schemes.map { ($0.name, $0.toJSONValue()) }
        if schemesPairs.count > 0 {
            dict["schemes"] = Dictionary(uniqueKeysWithValues: schemesPairs)
        }

        if settingGroups.count > 0 {
            dict["settingGroups"] = settingGroups.mapValues { $0.toJSONValue() }
        }

        return dict
    }
}
