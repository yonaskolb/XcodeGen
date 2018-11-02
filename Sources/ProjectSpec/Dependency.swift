import Foundation
import JSONUtilities

public struct Dependency: Equatable {

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool?
    public var removeHeaders: Bool = true
    public var link: Bool?
    public var implicit: Bool = false
    public var sdkRoot: Bool = false
    public var weakLink: Bool = false

    public init(
        type: DependencyType,
        reference: String,
        embed: Bool? = nil,
        codeSign: Bool? = nil,
        link: Bool? = nil,
        implicit: Bool = false,
        sdkRoot: Bool = false,
        weakLink: Bool = false
    ) {
        self.type = type
        self.reference = reference
        self.embed = embed
        self.codeSign = codeSign
        self.link = link
        self.sdkRoot = sdkRoot
        self.implicit = implicit
        self.weakLink = weakLink
    }

    public enum DependencyType {
        case target
        case framework
        case carthage
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
        } else {
            throw SpecParsingError.invalidDependency(jsonDictionary)
        }

        embed = jsonDictionary.json(atKeyPath: "embed")
        codeSign = jsonDictionary.json(atKeyPath: "codeSign")
        link = jsonDictionary.json(atKeyPath: "link")

        if let bool: Bool = jsonDictionary.json(atKeyPath: "removeHeaders") {
            removeHeaders = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "implicit") {
            implicit = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "sdkRoot") {
            sdkRoot = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "weak") {
            weakLink = bool
        }
    }
}
