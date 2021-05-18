import Foundation
import JSONUtilities

public struct Config: Hashable {
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

extension Config {

    public func matchesVariant(_ variant: String, for type: ConfigType) -> Bool {
        guard self.type == type else { return false }
        let nameWithoutType = self.name.lowercased()
            .replacingOccurrences(of: type.name.lowercased(), with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " -_()"))
        return nameWithoutType == variant.lowercased()
    }
}

public extension Collection where Element == Config {
    func first(including configVariant: String, for type: ConfigType) -> Config? {
        first { $0.matchesVariant(configVariant, for: type) }
    }
}

