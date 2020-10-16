import Foundation
import JSONUtilities
import Version

public struct SpecOptions: Equatable {
    public static let settingPresetsDefault = SettingPresets.all
    public static let createIntermediateGroupsDefault = false
    public static let transitivelyLinkDependenciesDefault = false
    public static let groupSortPositionDefault = GroupSortPosition.bottom
    public static let generateEmptyDirectoriesDefault = false
    public static let findCarthageFrameworksDefault = false
    public static let useBaseInternationalizationDefault = true

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
    public var groupOrdering: [GroupOrdering]
    public var fileTypes: [String: FileType]
    public var generateEmptyDirectories: Bool
    public var findCarthageFrameworks: Bool
    public var localPackagesGroup: String?
    public var preGenCommand: String?
    public var postGenCommand: String?
    public var useBaseInternationalization: Bool

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
        createIntermediateGroups: Bool = createIntermediateGroupsDefault,
        bundleIdPrefix: String? = nil,
        settingPresets: SettingPresets = settingPresetsDefault,
        developmentLanguage: String? = nil,
        indentWidth: UInt? = nil,
        tabWidth: UInt? = nil,
        usesTabs: Bool? = nil,
        xcodeVersion: String? = nil,
        deploymentTarget: DeploymentTarget = .init(),
        disabledValidations: [ValidationType] = [],
        defaultConfig: String? = nil,
        transitivelyLinkDependencies: Bool = transitivelyLinkDependenciesDefault,
        groupSortPosition: GroupSortPosition = groupSortPositionDefault,
        groupOrdering: [GroupOrdering] = [],
        fileTypes: [String: FileType] = [:],
        generateEmptyDirectories: Bool = generateEmptyDirectoriesDefault,
        findCarthageFrameworks: Bool = findCarthageFrameworksDefault,
        localPackagesGroup: String? = nil,
        preGenCommand: String? = nil,
        postGenCommand: String? = nil,
        useBaseInternationalization: Bool = useBaseInternationalizationDefault
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
        self.groupOrdering = groupOrdering
        self.fileTypes = fileTypes
        self.generateEmptyDirectories = generateEmptyDirectories
        self.findCarthageFrameworks = findCarthageFrameworks
        self.localPackagesGroup = localPackagesGroup
        self.preGenCommand = preGenCommand
        self.postGenCommand = postGenCommand
        self.useBaseInternationalization = useBaseInternationalization
    }
}

extension SpecOptions: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let string: String = jsonDictionary.json(atKeyPath: "minimumXcodeGenVersion") {
            minimumXcodeGenVersion = try Version.parse(string)
        }

        carthageBuildPath = jsonDictionary.json(atKeyPath: "carthageBuildPath")
        carthageExecutablePath = jsonDictionary.json(atKeyPath: "carthageExecutablePath")
        bundleIdPrefix = jsonDictionary.json(atKeyPath: "bundleIdPrefix")
        settingPresets = jsonDictionary.json(atKeyPath: "settingPresets") ?? SpecOptions.settingPresetsDefault
        createIntermediateGroups = jsonDictionary.json(atKeyPath: "createIntermediateGroups") ?? SpecOptions.createIntermediateGroupsDefault
        developmentLanguage = jsonDictionary.json(atKeyPath: "developmentLanguage")
        usesTabs = jsonDictionary.json(atKeyPath: "usesTabs")
        xcodeVersion = jsonDictionary.json(atKeyPath: "xcodeVersion")
        indentWidth = (jsonDictionary.json(atKeyPath: "indentWidth") as Int?).flatMap(UInt.init)
        tabWidth = (jsonDictionary.json(atKeyPath: "tabWidth") as Int?).flatMap(UInt.init)
        deploymentTarget = jsonDictionary.json(atKeyPath: "deploymentTarget") ?? DeploymentTarget()
        disabledValidations = jsonDictionary.json(atKeyPath: "disabledValidations") ?? []
        defaultConfig = jsonDictionary.json(atKeyPath: "defaultConfig")
        transitivelyLinkDependencies = jsonDictionary.json(atKeyPath: "transitivelyLinkDependencies") ?? SpecOptions.transitivelyLinkDependenciesDefault
        groupSortPosition = jsonDictionary.json(atKeyPath: "groupSortPosition") ?? SpecOptions.groupSortPositionDefault
        groupOrdering = jsonDictionary.json(atKeyPath: "groupOrdering") ?? []
        generateEmptyDirectories = jsonDictionary.json(atKeyPath: "generateEmptyDirectories") ?? SpecOptions.generateEmptyDirectoriesDefault
        findCarthageFrameworks = jsonDictionary.json(atKeyPath: "findCarthageFrameworks") ?? SpecOptions.findCarthageFrameworksDefault
        localPackagesGroup = jsonDictionary.json(atKeyPath: "localPackagesGroup")
        preGenCommand = jsonDictionary.json(atKeyPath: "preGenCommand")
        postGenCommand = jsonDictionary.json(atKeyPath: "postGenCommand")
        useBaseInternationalization = jsonDictionary.json(atKeyPath: "useBaseInternationalization") ?? SpecOptions.useBaseInternationalizationDefault
        if jsonDictionary["fileTypes"] != nil {
            fileTypes = try jsonDictionary.json(atKeyPath: "fileTypes")
        } else {
            fileTypes = [:]
        }
    }
}

extension SpecOptions: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "deploymentTarget": deploymentTarget.toJSONValue(),
            "transitivelyLinkDependencies": transitivelyLinkDependencies,
            "groupSortPosition": groupSortPosition.rawValue,
            "disabledValidations": disabledValidations.map { $0.rawValue },
            "minimumXcodeGenVersion": minimumXcodeGenVersion?.description,
            "carthageBuildPath": carthageBuildPath,
            "carthageExecutablePath": carthageExecutablePath,
            "bundleIdPrefix": bundleIdPrefix,
            "developmentLanguage": developmentLanguage,
            "usesTabs": usesTabs,
            "xcodeVersion": xcodeVersion,
            "indentWidth": indentWidth.flatMap { Int($0) },
            "tabWidth": tabWidth.flatMap { Int($0) },
            "defaultConfig": defaultConfig,
            "localPackagesGroup": localPackagesGroup,
            "preGenCommand": preGenCommand,
            "postGenCommand": postGenCommand,
            "fileTypes": fileTypes
        ]

        if settingPresets != SpecOptions.settingPresetsDefault {
            dict["settingPresets"] = settingPresets.rawValue
        }
        if createIntermediateGroups != SpecOptions.createIntermediateGroupsDefault {
            dict["createIntermediateGroups"] = createIntermediateGroups
        }
        if generateEmptyDirectories != SpecOptions.generateEmptyDirectoriesDefault {
            dict["generateEmptyDirectories"] = generateEmptyDirectories
        }
        if findCarthageFrameworks != SpecOptions.findCarthageFrameworksDefault {
            dict["findCarthageFrameworks"] = findCarthageFrameworks
        }
        if useBaseInternationalization != SpecOptions.useBaseInternationalizationDefault {
            dict["useBaseInternationalization"] = useBaseInternationalization
        }

        return dict
    }
}

extension SpecOptions: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("carthageBuildPath"),
        ]
    }
}
