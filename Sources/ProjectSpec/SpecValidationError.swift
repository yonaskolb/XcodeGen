import Foundation

public struct SpecValidationError: Error, CustomStringConvertible {

    public var errors: [ValidationError]

    public enum ValidationError: Error, CustomStringConvertible {
        case invalidXcodeGenVersion(version: Version, minimumVersion: Version)
        case invalidTargetDependency(target: String, dependency: String)
        case invalidTargetSource(target: String, source: String)
        case invalidTargetConfigFile(target: String, configFile: String, config: String)
        case invalidTargetSchemeConfigVariant(target: String, configVariant: String, configType: ConfigType)
        case invalidTargetSchemeTest(target: String, testTarget: String)
        case invalidSchemeTarget(scheme: String, target: String)
        case invalidSchemeConfig(scheme: String, config: String)
        case invalidConfigFile(configFile: String, config: String)
        case invalidBuildSettingConfig(String)
        case invalidSettingsGroup(String)
        case invalidBuildScriptPath(target: String, name: String?, path: String)
        case invalidFileGroup(String)
        case invalidConfigFileConfig(String)
        case missingConfigForTargetScheme(target: String, configType: ConfigType)
        case missingDefaultConfig(configName: String)

        public var description: String {
            switch self {
            case let .invalidXcodeGenVersion(version, minimumVersion):
                return "XcodeGen version is \(version), but minimum required version specified as \(minimumVersion)"
            case let .invalidTargetDependency(target, dependency):
                return "Target \(target.quoted) has invalid dependency: \(dependency.quoted)"
            case let .invalidTargetConfigFile(target, configFile, config):
                return "Target \(target.quoted) has invalid config file \(configFile.quoted) for config \(config.quoted)"
            case let .invalidTargetSource(target, source):
                return "Target \(target.quoted) has a missing source directory \(source.quoted)"
            case let .invalidTargetSchemeConfigVariant(target, configVariant, configType):
                return "Target \(target.quoted) has an invalid scheme config variant which requires a config that has a \(configType.rawValue.quoted) type and contains the name \(configVariant.quoted)"
            case let .invalidTargetSchemeTest(target, test):
                return "Target \(target.quoted) scheme has invalid test \(test.quoted)"
            case let .invalidConfigFile(configFile, config):
                return "Invalid config file \(configFile.quoted) for config \(config.quoted)"
            case let .invalidSchemeTarget(scheme, target):
                return "Scheme \(scheme.quoted) has invalid build target \(target.quoted)"
            case let .invalidSchemeConfig(scheme, config):
                return "Scheme \(scheme.quoted) has invalid build configuration \(config.quoted)"
            case let .invalidBuildSettingConfig(config):
                return "Build setting has invalid build configuration \(config.quoted)"
            case let .invalidSettingsGroup(group):
                return "Invalid settings group \(group.quoted)"
            case let .invalidBuildScriptPath(target, name, path):
                return "Target \(target.quoted) has a script \(name != nil ? "\(name!.quoted) which has a " : "")path that doesn't exist \(path.quoted)"
            case let .invalidFileGroup(group):
                return "Invalid file group \(group.quoted)"
            case let .invalidConfigFileConfig(config):
                return "Config file has invalid config \(config.quoted)"
            case let .missingConfigForTargetScheme(target, configType):
                return "Target \(target.quoted) is missing a config of type \(configType.rawValue) to generate its scheme"
            case let .missingDefaultConfig(name):
                return "Default configuration \(name) doesn't exist"
            }
        }
    }

    public var description: String {
        let title: String
        if errors.count == 1 {
            title = "Spec validation error: "
        } else {
            title = "\(errors.count) Spec validations errors:\n\t- "
        }
        return "\(title)" + errors.map { $0.description }.joined(separator: "\n\t- ")
    }
}
