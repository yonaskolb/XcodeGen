import Foundation
import JSONUtilities
import xcproj

public struct SpecOptions: Equatable {

    public var carthageBuildPath: String?
    public var carthageExecutablePath: String?
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
    public var defaultConfig: String?
    public var transitivelyLinkDependencies: Bool

    public enum ValidationType: String {
        case missingConfigs
    }

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
        carthageExecutablePath: String? = nil,
        createIntermediateGroups: Bool = false,
        bundleIdPrefix: String? = nil,
        settingPresets: SettingPresets = .all,
        developmentLanguage: String? = nil,
        indentWidth: UInt? = nil,
        tabWidth: UInt? = nil,
        usesTabs: Bool? = nil,
        xcodeVersion: String? = nil,
        deploymentTarget: DeploymentTarget = .init(),
        disabledValidations: [ValidationType] = [],
        defaultConfig: String? = nil,
        transitivelyLinkDependencies: Bool = false
    ) {
        self.carthageBuildPath = carthageBuildPath
        self.carthageExecutablePath = carthageExecutablePath
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
        self.defaultConfig = defaultConfig
        self.transitivelyLinkDependencies = transitivelyLinkDependencies
    }
}

extension SpecOptions: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
        carthageExecutablePath = jsonDictionary.json(atKeyPath: "carthageExecutablePath")
        bundleIdPrefix = jsonDictionary.json(atKeyPath: "bundleIdPrefix")
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? .all
        createIntermediateGroups = jsonDictionary.json(atKeyPath: "createIntermediateGroups") ?? false
        developmentLanguage = jsonDictionary.json(atKeyPath: "developmentLanguage")
        usesTabs = jsonDictionary.json(atKeyPath: "usesTabs")
        xcodeVersion = jsonDictionary.json(atKeyPath: "xcodeVersion")
        indentWidth = (jsonDictionary.json(atKeyPath: "indentWidth") as Int?).flatMap(UInt.init)
        tabWidth = (jsonDictionary.json(atKeyPath: "tabWidth") as Int?).flatMap(UInt.init)
        deploymentTarget = jsonDictionary.json(atKeyPath: "deploymentTarget") ?? DeploymentTarget()
        disabledValidations = jsonDictionary.json(atKeyPath: "disabledValidations") ?? []
        defaultConfig = jsonDictionary.json(atKeyPath: "defaultConfig")
        transitivelyLinkDependencies = jsonDictionary.json(atKeyPath: "transitivelyLinkDependencies") ?? false
    }
}
