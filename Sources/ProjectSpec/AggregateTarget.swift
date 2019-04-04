import Foundation
import JSONUtilities

public struct AggregateTarget: ProjectTarget {
    public var name: String
    public var targets: [String]
    public var settings: Settings
    public var buildScripts: [BuildScript]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?
    public var attributes: [String: Any]

    public init(
        name: String,
        targets: [String],
        settings: Settings = .empty,
        configFiles: [String: String] = [:],
        buildScripts: [BuildScript] = [],
        scheme: TargetScheme? = nil,
        attributes: [String: Any] = [:]
    ) {
        self.name = name
        self.targets = targets
        self.settings = settings
        self.configFiles = configFiles
        self.buildScripts = buildScripts
        self.scheme = scheme
        self.attributes = attributes
    }
}

extension AggregateTarget: CustomStringConvertible {

    public var description: String {
        return "\(name)\(targets.isEmpty ? "" : ": \(targets.joined(separator: ", "))")"
    }
}

extension AggregateTarget: Equatable {

    public static func == (lhs: AggregateTarget, rhs: AggregateTarget) -> Bool {
        return lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
            lhs.settings == rhs.settings &&
            lhs.configFiles == rhs.configFiles &&
            lhs.buildScripts == rhs.buildScripts &&
            lhs.scheme == rhs.scheme &&
            NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

extension AggregateTarget: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = jsonDictionary.json(atKeyPath: "name") ?? name
        targets = jsonDictionary.json(atKeyPath: "targets") ?? []
        settings = jsonDictionary.json(atKeyPath: "settings") ?? .empty
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        buildScripts = jsonDictionary.json(atKeyPath: "buildScripts") ?? []
        scheme = jsonDictionary.json(atKeyPath: "scheme")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
    }
}

extension AggregateTarget: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: JSONDictionary = [:]

        let settingsDict = settings.toJSONValue()
        if settingsDict.count > 0 {
            dict["settings"] = settingsDict
        }
        
        if targets.count > 0 {
            dict["targets"] = targets
        }
        if configFiles.count > 0 {
            dict["configFiles"] = configFiles
        }
        if attributes.count > 0 {
            dict["attributes"] = attributes
        }
        if buildScripts.count > 0 {
            dict["buildScripts"] = buildScripts.map { $0.toJSONValue() }
        }
        if let scheme = scheme {
            dict["scheme"] = scheme.toJSONValue()
        }

        return dict
    }
}

extension AggregateTarget: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .dictionary([
                .string("configFiles"),
                .object("buildScripts", BuildScript.pathProperties),
            ]),
        ]
    }
}
