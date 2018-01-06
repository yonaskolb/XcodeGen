import Foundation
import xcproj
import JSONUtilities

public struct Dependency: Equatable {

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool = true
    public var removeHeaders: Bool = true
    public var link: Bool = true
    public var implicit: Bool = false

    public init(
        type: DependencyType,
        reference: String,
        embed: Bool? = nil,
        link: Bool = true,
        implicit: Bool = false
    ) {
        self.type = type
        self.reference = reference
        self.embed = embed
        self.link = link
        self.implicit = implicit
    }

    public enum DependencyType {
        case target
        case framework
        case carthage
        case resourceBundle
    }

    public static func == (lhs: Dependency, rhs: Dependency) -> Bool {
        return lhs.reference == rhs.reference &&
            lhs.type == rhs.type &&
            lhs.codeSign == rhs.codeSign &&
            lhs.removeHeaders == rhs.removeHeaders &&
            lhs.embed == rhs.embed &&
            lhs.link == rhs.link
    }

    public var buildSettings: [String: Any] {
        var attributes: [String] = []
        if codeSign {
            attributes.append("CodeSignOnCopy")
        }
        if removeHeaders {
            attributes.append("RemoveHeadersOnCopy")
        }
        return ["ATTRIBUTES": attributes]
    }
}

extension Dependency: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let target: String = jsonDictionary.json(atKeyPath: "target") {
            type = .target
            reference = target
        } else if let framework: String = jsonDictionary.json(atKeyPath: "framework") {
            type = .framework
            reference = framework
        } else if let carthage: String = jsonDictionary.json(atKeyPath: "carthage") {
            type = .carthage
            reference = carthage
        } else if let resourceBundle: String = jsonDictionary.json(atKeyPath: "resourceBundle") {
            type = .resourceBundle
            reference = resourceBundle
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }

        embed = jsonDictionary.json(atKeyPath: "embed")

        if let bool: Bool = jsonDictionary.json(atKeyPath: "link") {
            link = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "codeSign") {
            codeSign = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "removeHeaders") {
            removeHeaders = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "implicit") {
            implicit = bool
        }
    }
}
