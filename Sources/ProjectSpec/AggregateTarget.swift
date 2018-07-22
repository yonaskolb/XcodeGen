import Foundation
import JSONUtilities

public struct AggregateTarget: ProjectTarget, Equatable {
    public var name: String
    public var targets: [String]
    public var settings: Settings
    public var buildScripts: [BuildScript]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?

    public init(
        name: String,
        targets: [String],
        settings: Settings = .empty,
        configFiles: [String: String] = [:],
        buildScripts: [BuildScript] = [],
        scheme: TargetScheme? = nil
        ) {
        self.name = name
        self.targets = targets
        self.settings = settings
        self.configFiles = configFiles
        self.buildScripts = buildScripts
        self.scheme = scheme
    }
}

extension AggregateTarget: CustomStringConvertible {

    public var description: String {
        return "\(name): \(targets.joined(separator: ", "))"
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
    }
}
