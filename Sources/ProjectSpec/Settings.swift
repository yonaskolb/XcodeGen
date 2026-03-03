import Foundation
import JSONUtilities
import PathKit
import XcodeProj

public struct Settings: Equatable, JSONObjectConvertible, CustomStringConvertible {

    public var buildSettings: BuildSettings
    public var configSettings: [String: Settings]
    public var groups: [String]

    public init(buildSettings: BuildSettings = [:], configSettings: [String: Settings] = [:], groups: [String] = []) {
        self.buildSettings = buildSettings
        self.configSettings = configSettings
        self.groups = groups
    }

    public static let empty: Settings = Settings(buildSettings: [:])

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["configs"] != nil || jsonDictionary["groups"] != nil || jsonDictionary["base"] != nil {
            groups = jsonDictionary.json(atKeyPath: "groups") ?? jsonDictionary.json(atKeyPath: "presets") ?? []
            let buildSettingsDictionary: JSONDictionary = jsonDictionary.json(atKeyPath: "base") ?? [:]
            buildSettings = buildSettingsDictionary.mapValues { BuildSetting(any: $0) }

            self.configSettings = try Self.extractValidConfigs(from: jsonDictionary)
        } else {
            buildSettings = jsonDictionary.mapValues { BuildSetting(any: $0) }
            configSettings = [:]
            groups = []
        }
    }

    /// Extracts and validates the `configs` mapping from the given JSON dictionary.
    /// - Parameter jsonDictionary: The JSON dictionary to extract `configs` from.
    /// - Returns: A dictionary mapping configuration names to `Settings` objects.
    private static func extractValidConfigs(from jsonDictionary: JSONDictionary) throws -> [String: Settings] {
        guard let configSettings = jsonDictionary["configs"] as? JSONDictionary else {
            return [:]
        }

        let invalidConfigKeys = Set(
            configSettings.filter { !($0.value is JSONDictionary) }
                .map(\.key)
        )

        guard invalidConfigKeys.isEmpty else {
            throw SpecParsingError.invalidConfigsMappingFormat(keys: invalidConfigKeys)
        }

        return try jsonDictionary.json(atKeyPath: "configs")
    }

    public static func == (lhs: Settings, rhs: Settings) -> Bool {
        lhs.buildSettings == rhs.buildSettings &&
            lhs.configSettings == rhs.configSettings &&
            lhs.groups == rhs.groups
    }

    public var description: String {
        var string: String = ""
        if !buildSettings.isEmpty {
            let buildSettingDescription = buildSettings.map { "\($0) = \($1)" }.joined(separator: "\n")
            if !configSettings.isEmpty || !groups.isEmpty {
                string += "base:\n  " + buildSettingDescription.replacingOccurrences(of: "(.)\n", with: "$1\n  ", options: .regularExpression, range: nil)
            } else {
                string += buildSettingDescription
            }
        }
        if !configSettings.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            for (config, buildSettings) in configSettings {
                if !buildSettings.description.isEmpty {
                    string += "configs:\n"
                    string += "  \(config):\n    " + buildSettings.description.replacingOccurrences(of: "(.)\n", with: "$1\n    ", options: .regularExpression, range: nil)
                }
            }
        }
        if !groups.isEmpty {
            if !string.isEmpty {
                string += "\n"
            }
            string += "groups:\n  \(groups.joined(separator: "\n  "))"
        }
        return string
    }
}

extension Settings: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, BuildSetting)...) {
        var buildSettings: BuildSettings = [:]
        elements.forEach { buildSettings[$0.0] = $0.1 }
        self.init(buildSettings: buildSettings)
    }
}

extension Dictionary where Key == String {

    public func merged(_ dictionary: [Key: Value]) -> [Key: Value] {
        var mergedDictionary = self
        mergedDictionary.merge(dictionary)
        return mergedDictionary
    }

    public mutating func merge(_ dictionary: [Key: Value]) {
        for (key, value) in dictionary {
            self[key] = value
        }
    }
}

public func += (lhs: inout BuildSettings, rhs: BuildSettings?) {
    guard let rhs = rhs else { return }
    lhs.merge(rhs)
}

extension BuildSetting {

    public init(any value: Any) {
        if let array = value as? [String] {
            self = .array(array)
        } else if let bool = value as? Bool {
            self = .init(booleanLiteral: bool)
        } else {
            self = .string("\(value)")
        }
    }

    public func toAny() -> Any {
        switch self {
        case let .string(value): return value
        case let .array(value): return value
        }
    }
}

extension ProjectAttribute {

    public init(any value: Any) {
        if let array = value as? [String] {
            self = .array(array)
        } else if let object = value as? PBXObject {
            self = .targetReference(object)
        } else {
            self = .string("\(value)")
        }
    }
}

extension Settings: JSONEncodable {
    public func toJSONValue() -> Any {
        let anySettings = buildSettings.mapValues { $0.toAny() }
        if groups.count > 0 || configSettings.count > 0 {
            return [
                "base": anySettings,
                "groups": groups,
                "configs": configSettings.mapValues { $0.toJSONValue() },
            ] as [String : Any]
        }
        return anySettings
    }
}
