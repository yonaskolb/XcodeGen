import Foundation
import JSONUtilities

public struct SpecOptions: Equatable {

    public var minimumXcodeGenVersion: Version?
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
    public var groupSortPosition: GroupSortPosition
    public var generateEmptyDirectories: Bool
    public var findCarthageFrameworks: Bool

    public enum ValidationType: String {
        case missingConfigs
        case missingConfigFiles
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

    /// Where groups are sorted in relation to other files
    public enum GroupSortPosition: String {
        /// groups are at the top
        case top
        /// groups are at the bottom
        case bottom
        /// groups are sorted with the rest of the files
        case none
    }

    public init(
        minimumXcodeGenVersion: Version? = nil,
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
        transitivelyLinkDependencies: Bool = false,
        groupSortPosition: GroupSortPosition = .bottom,
        generateEmptyDirectories: Bool = false,
        findCarthageFrameworks: Bool = false
    ) {
        self.minimumXcodeGenVersion = minimumXcodeGenVersion
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
        self.groupSortPosition = groupSortPosition
        self.generateEmptyDirectories = generateEmptyDirectories
        self.findCarthageFrameworks = findCarthageFrameworks
    }
}

extension SpecOptions: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let string: String = jsonDictionary.json(atKeyPath: "minimumXcodeGenVersion") {
            minimumXcodeGenVersion = try Version(string)
        }

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
        groupSortPosition = jsonDictionary.json(atKeyPath: "groupSortPosition") ?? .bottom
        generateEmptyDirectories = jsonDictionary.json(atKeyPath: "generateEmptyDirectories") ?? false
        findCarthageFrameworks = jsonDictionary.json(atKeyPath: "findCarthageFrameworks") ?? false
    }
}

extension SpecOptions: JSONDictionaryEncodable {
    public func toJSONDictionary() -> JSONDictionary {
        var dict: JSONDictionary = [
            "deploymentTarget": deploymentTarget.toJSONDictionary(),
            "transitivelyLinkDependencies": transitivelyLinkDependencies,
            "groupSortPosition": groupSortPosition.rawValue,
        ]

        if settingPresets != .all {
            dict["settingPresets"] = settingPresets.rawValue
        }
        if createIntermediateGroups {
            dict["createIntermediateGroups"] = createIntermediateGroups
        }
        if generateEmptyDirectories {
            dict["generateEmptyDirectories"] = generateEmptyDirectories
        }
        if findCarthageFrameworks {
            dict["findCarthageFrameworks"] = findCarthageFrameworks
        }
        if disabledValidations.count > 0 {
            dict["disabledValidations"] = disabledValidations.map { $0.rawValue }
        }
        if let minimumXcodeGenVersion = minimumXcodeGenVersion {
            dict["minimumXcodeGenVersion"] = minimumXcodeGenVersion.string
        }
        if let carthageBuildPath = carthageBuildPath {
            dict["carthageBuildPath"] = carthageBuildPath
        }
        if let carthageExecutablePath = carthageExecutablePath {
            dict["carthageExecutablePath"] = carthageExecutablePath
        }
        if let bundleIdPrefix = bundleIdPrefix {
            dict["bundleIdPrefix"] = bundleIdPrefix
        }
        if let developmentLanguage = developmentLanguage {
            dict["developmentLanguage"] = developmentLanguage
        }
        if let usesTabs = usesTabs {
            dict["usesTabs"] = usesTabs
        }
        if let xcodeVersion = xcodeVersion {
            dict["xcodeVersion"] = xcodeVersion
        }
        if let indentWidth = indentWidth {
            dict["indentWidth"] = Int(indentWidth)
        }
        if let tabWidth = tabWidth {
            dict["tabWidth"] = Int(tabWidth)
        }
        if let defaultConfig = defaultConfig {
            dict["defaultConfig"] = defaultConfig
        }

        return dict
    }
}

extension SpecOptions: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .string("carthageBuildPath"),
        ]
    }
}
