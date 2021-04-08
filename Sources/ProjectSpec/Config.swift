import Foundation
import JSONUtilities

public struct Config: Equatable {
    public var name: String
    public var type: ConfigType?

    public init(name: String, type: ConfigType? = nil) {
        self.name = name
        self.type = type
    }

    public static var defaultConfigs: [Config] = [Config(name: ConfigType.debug.name, type: .debug), Config(name: ConfigType.release.name, type: .release)]
}

public enum ConfigType: String {
    case debug
    case release
    
    public var name: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

public extension Collection where Element == Config {
    func first(with configVariant: String, for type: ConfigType) -> Config? {
        first(where: { $0.type == type && $0.name.variantName(for: $0.type) == configVariant })
    }
}

private extension String {
    func variantName(for configType: ConfigType? ) -> String {
        replacingOccurrences(of: configType?.name ?? "", with: "")
            .trimmingCharacters(in: CharacterSet.whitespaces)
    }
}
