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
