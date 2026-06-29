import Foundation
import JSONUtilities

/// Swift Package Registry (SE-0292) configuration.
///
/// XcodeGen serializes this into the generated project's
/// `project.xcworkspace/xcshareddata/swiftpm/configuration/registries.json`, which is the
/// file SwiftPM and Xcode read to resolve registry (`.package(id:)`) dependencies. Xcode
/// has no project-level (pbxproj) representation for registry packages, so this configuration
/// file is the supported way to point a generated project at a registry.
public struct SwiftPackageRegistries: Equatable {

    /// A single registry endpoint.
    public struct Registry: Equatable {

        /// The registry base URL, e.g. `https://tuist.dev/api/registry/swift`.
        public var url: String

        /// Whether the registry implements the SE-0292 availability API. Defaults to `false`,
        /// matching what `swift package-registry set` writes.
        public var supportsAvailability: Bool

        public init(url: String, supportsAvailability: Bool = false) {
            self.url = url
            self.supportsAvailability = supportsAvailability
        }
    }

    /// The default registry, written under SwiftPM's `[default]` key.
    public var defaultRegistry: Registry?

    /// Scoped registries keyed by package scope. A package whose identity is `<scope>.<name>`
    /// resolves from the matching scope's registry.
    public var scopes: [String: Registry]

    public init(defaultRegistry: Registry? = nil, scopes: [String: Registry] = [:]) {
        self.defaultRegistry = defaultRegistry
        self.scopes = scopes
    }

    /// Whether there is anything to write. When empty, XcodeGen writes no registries.json.
    public var isEmpty: Bool {
        defaultRegistry == nil && scopes.isEmpty
    }
}

extension SwiftPackageRegistries {

    /// Errors raised while parsing a `registries` block.
    public enum ParsingError: Error, CustomStringConvertible {
        case invalidRegistry(Any)
        case missingURL(JSONDictionary)

        public var description: String {
            switch self {
            case let .invalidRegistry(value):
                return "Invalid registry \"\(value)\". Expected a URL string or a mapping with a \"url\" key."
            case let .missingURL(dictionary):
                return "Registry \"\(dictionary)\" is missing a \"url\"."
            }
        }
    }
}

extension SwiftPackageRegistries.Registry {

    /// Decodes a registry from either a bare URL string or a `{ url, supportsAvailability }` mapping.
    init(jsonValue: Any) throws {
        if let url = jsonValue as? String {
            self.init(url: url)
        } else if let dictionary = jsonValue as? JSONDictionary {
            guard let url = dictionary["url"] as? String else {
                throw SwiftPackageRegistries.ParsingError.missingURL(dictionary)
            }
            let supportsAvailability = (dictionary["supportsAvailability"] as? Bool) ?? false
            self.init(url: url, supportsAvailability: supportsAvailability)
        } else {
            throw SwiftPackageRegistries.ParsingError.invalidRegistry(jsonValue)
        }
    }
}

extension SwiftPackageRegistries: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let defaultValue = jsonDictionary["default"] {
            defaultRegistry = try Registry(jsonValue: defaultValue)
        } else {
            defaultRegistry = nil
        }
        if let scopesDictionary = jsonDictionary["scopes"] as? JSONDictionary {
            scopes = try scopesDictionary.mapValues { try Registry(jsonValue: $0) }
        } else {
            scopes = [:]
        }
    }
}

extension SwiftPackageRegistries.Registry: JSONEncodable {

    public func toJSONValue() -> Any {
        // Use the compact URL-string form unless a non-default flag needs to be preserved.
        if supportsAvailability {
            return [
                "url": url,
                "supportsAvailability": supportsAvailability,
            ] as JSONDictionary
        }
        return url
    }
}

extension SwiftPackageRegistries: JSONEncodable {

    public func toJSONValue() -> Any {
        var dictionary: JSONDictionary = [:]
        if let defaultRegistry = defaultRegistry {
            dictionary["default"] = defaultRegistry.toJSONValue()
        }
        if !scopes.isEmpty {
            dictionary["scopes"] = scopes.mapValues { $0.toJSONValue() }
        }
        return dictionary
    }
}

extension SwiftPackageRegistries {

    /// The on-disk `registries.json` representation that SwiftPM and Xcode read.
    struct File: Encodable {
        struct Entry: Encodable {
            let supportsAvailability: Bool
            let url: String
        }

        let authentication: [String: String]
        let registries: [String: Entry]
        let version: Int
    }

    func makeFile() -> File {
        var entries: [String: File.Entry] = [:]
        if let defaultRegistry = defaultRegistry {
            entries["[default]"] = File.Entry(supportsAvailability: defaultRegistry.supportsAvailability, url: defaultRegistry.url)
        }
        for (scope, registry) in scopes {
            entries[scope] = File.Entry(supportsAvailability: registry.supportsAvailability, url: registry.url)
        }
        return File(authentication: [:], registries: entries, version: 1)
    }

    /// Serializes the configuration to `registries.json` bytes: sorted keys, pretty printed,
    /// and slashes left unescaped to match the output of `swift package-registry set`.
    public func registriesJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(makeFile())
    }
}
