import Foundation
import JSONUtilities

/// Specifies the use of a plug-in product in a target.
public struct BuildToolPlugin: Equatable {

    /// The name of the plug-in target.
    public var plugin: String
    /// The name of the package that defines the plug-in target.
    public var package: String
    
    public init(
        plugin: String,
        package: String
    ) {
        self.plugin = plugin
        self.package = package
    }
}

extension BuildToolPlugin: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let plugin: String = jsonDictionary.json(atKeyPath: "plugin") {
            self.plugin = plugin
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }
        
        if let package: String = jsonDictionary.json(atKeyPath: "package") {
            self.package = package
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }
    }
}

extension BuildToolPlugin {
    public var uniqueID: String {
        return "\(plugin)/\(package)"
    }
}

extension BuildToolPlugin: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(package)
    }
}

extension BuildToolPlugin: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "plugin": plugin,
            "package": package
        ]
    }
}
