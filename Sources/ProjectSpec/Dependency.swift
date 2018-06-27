import Foundation
import JSONUtilities
import xcproj

public struct Dependency: Equatable {

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool?
    public var removeHeaders: Bool = true
    public var link: Bool = true
    public var implicit: Bool = false

    public init(
        type: DependencyType,
        reference: String,
        embed: Bool? = nil,
        codeSign: Bool? = nil,
        link: Bool = true,
        implicit: Bool = false
    ) {
        self.type = type
        self.reference = reference
        self.embed = embed
        self.codeSign = codeSign
        self.link = link
        self.implicit = implicit
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

        if let bool: Bool = jsonDictionary.json(atKeyPath: "link") {
            link = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "removeHeaders") {
            removeHeaders = bool
        }
        if let bool: Bool = jsonDictionary.json(atKeyPath: "implicit") {
            implicit = bool
        }
    }
}
