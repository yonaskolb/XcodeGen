import Foundation
import JSONUtilities
import XcodeProj

public struct AggregateTarget: ProjectTarget {
    public var name: String
    public var type: PBXProductType = .none
    public var targets: [String]
    public var settings: Settings
    public var buildScripts: [BuildScript]
    public var buildToolPlugins: [BuildToolPlugin]
    public var configFiles: [String: String]
    public var scheme: TargetScheme?
    public var attributes: [String: Any]

    public init(
        name: String,
        targets: [String],
        settings: Settings = .empty,
        configFiles: [String: String] = [:],
        buildScripts: [BuildScript] = [],
        buildToolPlugins: [BuildToolPlugin] = [],
        scheme: TargetScheme? = nil,
        attributes: [String: Any] = [:]
    ) {
        self.name = name
        self.targets = targets
        self.settings = settings
        self.configFiles = configFiles
        self.buildScripts = buildScripts
        self.buildToolPlugins = buildToolPlugins
        self.scheme = scheme
        self.attributes = attributes
    }
}

extension AggregateTarget: CustomStringConvertible {

    public var description: String {
        "\(name)\(targets.isEmpty ? "" : ": \(targets.joined(separator: ", "))")"
    }
}

extension AggregateTarget: Equatable {

    public static func == (lhs: AggregateTarget, rhs: AggregateTarget) -> Bool {
        lhs.name == rhs.name &&
            lhs.targets == rhs.targets &&
            lhs.settings == rhs.settings &&
            lhs.configFiles == rhs.configFiles &&
            lhs.buildScripts == rhs.buildScripts &&
            lhs.buildToolPlugins == rhs.buildToolPlugins &&
            lhs.scheme == rhs.scheme &&
            NSDictionary(dictionary: lhs.attributes).isEqual(to: rhs.attributes)
    }
}

extension AggregateTarget: NamedJSONDictionaryConvertible {

    public init(name: String, jsonDictionary: JSONDictionary) throws {
        self.name = jsonDictionary.json(atKeyPath: "name") ?? name
        targets = jsonDictionary.json(atKeyPath: "targets") ?? []
        settings = try BuildSettingsParser(jsonDictionary: jsonDictionary).extract()
        configFiles = jsonDictionary.json(atKeyPath: "configFiles") ?? [:]
        buildScripts = jsonDictionary.json(atKeyPath: "buildScripts") ?? []
        buildToolPlugins = jsonDictionary.json(atKeyPath: "buildToolPlugins") ?? []
        scheme = jsonDictionary.json(atKeyPath: "scheme")
        attributes = jsonDictionary.json(atKeyPath: "attributes") ?? [:]
    }
}

extension AggregateTarget: JSONEncodable {
    public func toJSONValue() -> Any {
        [
            "settings": settings.toJSONValue(),
            "targets": targets,
            "configFiles": configFiles,
            "attributes": attributes,
            "buildScripts": buildScripts.map { $0.toJSONValue() },
            "buildToolPlugins": buildToolPlugins.map { $0.toJSONValue() },
            "scheme": scheme?.toJSONValue(),
        ] as [String: Any?]
    }
}

extension AggregateTarget: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .string("configFiles"),
                .object("buildScripts", BuildScript.pathProperties),
            ]),
        ]
    }
}
