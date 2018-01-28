import Foundation
import JSONUtilities
import PathKit
import xcproj
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

    public struct Options: Equatable {
        public var carthageBuildPath: String?
        public var createIntermediateGroups: Bool
        public var bundleIdPrefix: String?
        public var settingPresets: SettingPresets
        public var disabledValidations: [ValidationType]
        public var developmentLanguage: String?
        public var usesTabs: Bool?
        public var tabWidth: UInt?
        public var indentWidth: UInt?
        public var xcodeVersion: String?
        public var deploymentTarget: DeploymentTarget

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

        public init(
            carthageBuildPath: String? = nil,
            createIntermediateGroups: Bool = false,
            bundleIdPrefix: String? = nil,
            settingPresets: SettingPresets = .all,
            developmentLanguage: String? = nil,
            indentWidth: UInt? = nil,
            tabWidth: UInt? = nil,
            usesTabs: Bool? = nil,
            xcodeVersion: String? = nil,
            deploymentTarget: DeploymentTarget = .init(),
            disabledValidations: [ValidationType] = []
        ) {
            self.carthageBuildPath = carthageBuildPath
            self.createIntermediateGroups = createIntermediateGroups
            self.bundleIdPrefix = bundleIdPrefix
            self.settingPresets = settingPresets
            self.developmentLanguage = developmentLanguage
            self.tabWidth = tabWidth
            self.indentWidth = indentWidth
            self.usesTabs = usesTabs
            self.xcodeVersion = xcodeVersion
            self.deploymentTarget = deploymentTarget
            self.disabledValidations = disabledValidations
        }

        public static func == (lhs: ProjectSpec.Options, rhs: ProjectSpec.Options) -> Bool {
            return lhs.carthageBuildPath == rhs.carthageBuildPath &&
                lhs.bundleIdPrefix == rhs.bundleIdPrefix &&
                lhs.settingPresets == rhs.settingPresets &&
                lhs.createIntermediateGroups == rhs.createIntermediateGroups &&
                lhs.developmentLanguage == rhs.developmentLanguage &&
                lhs.tabWidth == rhs.tabWidth &&
                lhs.indentWidth == rhs.indentWidth &&
                lhs.usesTabs == rhs.usesTabs &&
                lhs.xcodeVersion == rhs.xcodeVersion &&
                lhs.deploymentTarget == rhs.deploymentTarget &&
                lhs.disabledValidations == rhs.disabledValidations
        }
    }

    public init(
        basePath: Path,
        name: String,
        configs: [Config] = Config.defaultConfigs,
        targets: [Target] = [],
        settings: Settings = .empty,
        settingGroups: [String: Settings] = [:],
        schemes: [Scheme] = [],
        options: Options = Options(),
        fileGroups: [String] = [],
        configFiles: [String: String] = [:],
        attributes: [String: Any] = [:]
    ) {
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
            string += "\nSetting Groups:\n\(indent)" + settingGroups.keys
                .sorted()
                .map { "⚙️  \($0)" }
                .joined(separator: "\n\(indent)")
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

extension ProjectSpec {

    public init(basePath: Path, jsonDictionary: JSONDictionary) throws {
        self.basePath = basePath
        let jsonDictionary = try ProjectSpec.filterJSON(jsonDictionary: jsonDictionary)
        name = try jsonDictionary.json(atKeyPath: "name")
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        settingGroups = jsonDictionary.json(atKeyPath: "settingGroups")
            ?? jsonDictionary.json(atKeyPath: "settingPresets") ?? [:]
        let configs: [String: String] = jsonDictionary.json(atKeyPath: "configs") ?? [:]
        self.configs = configs.isEmpty ? Config.defaultConfigs :
            configs.map { Config(name: $0, type: ConfigType(rawValue: $1)) }.sorted { $0.name < $1.name }
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
        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
        bundleIdPrefix = jsonDictionary.json(atKeyPath: "bundleIdPrefix")
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? .all
        createIntermediateGroups = jsonDictionary.json(atKeyPath: "createIntermediateGroups") ?? false
        developmentLanguage = jsonDictionary.json(atKeyPath: "developmentLanguage")
        usesTabs = jsonDictionary.json(atKeyPath: "usesTabs")
        indentWidth = (jsonDictionary.json(atKeyPath: "indentWidth") as Int?).flatMap(UInt.init)
        tabWidth = (jsonDictionary.json(atKeyPath: "tabWidth") as Int?).flatMap(UInt.init)
        deploymentTarget = jsonDictionary.json(atKeyPath: "deploymentTarget") ?? DeploymentTarget()
        disabledValidations = jsonDictionary.json(atKeyPath: "disabledValidations") ?? []
    }
}
