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
        basePath: Path,
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
                .map { "⚙️  \($0)" }
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

    public init(basePath: Path, jsonDictionary: JSONDictionary) throws {
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
        jsonDictionary = try Target.resolveTargetTemplates(jsonDictionary: jsonDictionary)
        jsonDictionary = try Target.resolveMultiplatformTargets(jsonDictionary: jsonDictionary)
        return jsonDictionary
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
        return configFiles.values.map{ Path($0) }
    }
}

