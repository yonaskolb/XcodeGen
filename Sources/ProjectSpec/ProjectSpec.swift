import Foundation
import xcproj
import JSONUtilities
import PathKit
import Yams

public struct ProjectSpec {
    
    public var basePath: Path
    public var name: String
    public var targets: [Target]
    public var settings: Settings
    public var settingGroups: [String: Settings]
    public var configs: [Config]
    public var schemes: [Scheme]
    public var options: Options
    public var attributes: [String: Any]
    public var fileGroups: [String]
    public var configFiles: [String: String]
    public var include: [String] = []

    public struct Options {
        fileprivate static let defaultXcodeVersion = "0910"
        
        public var currentXcodeVersion: String
        public var carthageBuildPath: String?
        public var createIntermediateGroups: Bool
        public var bundleIdPrefix: String?
        public var settingPresets: SettingPresets
        public var developmentLanguage: String?

        public enum SettingPresets: String {
            case all
            case none
            case project
            case targets

            public var applyTarget: Bool {
                switch self {
                case .all, .targets: return true
                default: return false
                }
            }

            public var applyProject: Bool {
                switch self {
                case .all, .project: return true
                default: return false
                }
            }
        }

        public init(currentXcodeVersion: String? = nil, carthageBuildPath: String? = nil, createIntermediateGroups: Bool = false, bundleIdPrefix: String? = nil, settingPresets: SettingPresets = .all, developmentLanguage: String? = nil) {
            self.currentXcodeVersion = currentXcodeVersion ?? Options.defaultXcodeVersion
            self.carthageBuildPath = carthageBuildPath
            self.createIntermediateGroups = createIntermediateGroups
            self.bundleIdPrefix = bundleIdPrefix
            self.settingPresets = settingPresets
            self.developmentLanguage = developmentLanguage
        }
    }

    public init(basePath: Path, name: String, configs: [Config] = Config.defaultConfigs, targets: [Target] = [], settings: Settings = .empty, settingGroups: [String: Settings] = [:], schemes: [Scheme] = [], options: Options = Options(), fileGroups: [String] = [], configFiles: [String: String] = [:], attributes: [String: Any] = [:]) {
        self.basePath = basePath
        self.name = name
        self.targets = targets
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
        return targets.first { $0.name == targetName }
    }

    public func getConfig(_ configName: String) -> Config? {
        return configs.first { $0.name == configName }
    }
}

extension ProjectSpec: CustomDebugStringConvertible {

    public var debugDescription: String {
        var string = "Name: \(name)"
        let indent = "  "
        if !include.isEmpty {
            string += "\nInclude:\n\(indent)" + include.map { "📄  \($0)" }.joined(separator: "\n\(indent)")
        }

        if !settingGroups.isEmpty {
            string += "\nSetting Groups:\n\(indent)" + settingGroups.keys.sorted().map { "⚙️  \($0)" }.joined(separator: "\n\(indent)")
        }

        if !targets.isEmpty {
            string += "\nTargets:\n\(indent)" + targets.map { $0.description }.joined(separator: "\n\(indent)")
        }

        return string
    }
}

extension ProjectSpec: Equatable {

    public static func == (lhs: ProjectSpec, rhs: ProjectSpec) -> Bool {
        return lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
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

extension ProjectSpec.Options: Equatable {

    public static func == (lhs: ProjectSpec.Options, rhs: ProjectSpec.Options) -> Bool {
        return lhs.currentXcodeVersion == rhs.currentXcodeVersion &&
            lhs.carthageBuildPath == rhs.carthageBuildPath &&
            lhs.bundleIdPrefix == rhs.bundleIdPrefix &&
            lhs.settingPresets == rhs.settingPresets &&
            lhs.createIntermediateGroups == rhs.createIntermediateGroups &&
            lhs.developmentLanguage == rhs.developmentLanguage
    }
}

extension ProjectSpec {

    public init(basePath: Path, jsonDictionary: JSONDictionary) throws {
        self.basePath = basePath
        let jsonDictionary = try ProjectSpec.filterJSON(jsonDictionary: jsonDictionary)
        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingGroups = jsonDictionary.json(atKeyPath: "settingGroups") ?? jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        let configs: [String: String] = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        self.configs = configs.isEmpty ? Config.defaultConfigs : configs.map { Config(name: $0, type: ConfigType(rawValue: $1)) }.sorted { $0.name < $1.name }
        targets = try jsonDictionary.json(atKeyPath: "targets").sorted { $0.name < $1.name }
        schemes = try jsonDictionary.json(atKeyPath: "schemes")
        fileGroups = jsonDictionary.json(atKeyPath: "fileGroups") ?? []
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
        include = jsonDictionary.json(atKeyPath: "include") ?? []
        if jsonDictionary["options"] != nil {
            options = try jsonDictionary.json(atKeyPath: "options")
        } else {
            options = Options()
        }
    }

    static func filterJSON(jsonDictionary: JSONDictionary) throws -> JSONDictionary {
        return try Target.generateCrossPlaformTargets(jsonDictionary: jsonDictionary)
    }
}

extension ProjectSpec.Options: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        currentXcodeVersion = jsonDictionary.json(atKeyPath: "currentXcodeVersion") ?? ProjectSpec.Options.defaultXcodeVersion
        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
        bundleIdPrefix = jsonDictionary.json(atKeyPath: "bundleIdPrefix")
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? .all
        createIntermediateGroups = jsonDictionary.json(atKeyPath: "createIntermediateGroups") ?? false
        developmentLanguage = jsonDictionary.json(atKeyPath: "developmentLanguage")
    }
}
