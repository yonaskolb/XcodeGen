import Foundation
import JSONUtilities

public struct Dependency: Equatable {
    public static let removeHeadersDefault = true
    public static let implicitDefault = false
    public static let weakLinkDefault = false

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool?
    public var removeHeaders: Bool = removeHeadersDefault
    public var link: Bool?
    public var implicit: Bool = implicitDefault
    public var weakLink: Bool = weakLinkDefault

    public init(
        type: DependencyType,
        reference: String,
        embed: Bool? = nil,
        codeSign: Bool? = nil,
        link: Bool? = nil,
        implicit: Bool = implicitDefault,
        weakLink: Bool = weakLinkDefault
    ) {
        self.type = type
        self.reference = reference
        self.embed = embed
        self.codeSign = codeSign
        self.link = link
        self.implicit = implicit
        self.weakLink = weakLink
    }

    public enum CarthageLinkType: String {
        case dynamic
        case `static`

        public static let `default` = dynamic
    }

    public enum DependencyType: Equatable {
        case target
        case framework
        case carthage(findFrameworks: Bool?, linkType: CarthageLinkType)
        case sdk(root: String?)
        case package(product: String?)
        case bundle
    }
}

extension Dependency {
    public var uniqueID: String {
        switch type {
        case .package(let product):
            if let product = product {
                return "\(reference)/\(product)"
            } else {
                return reference
            }
        default: return reference
        }
    }
}

extension Dependency: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(reference)
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
            let findFrameworks: Bool? = jsonDictionary.json(atKeyPath: "findFrameworks")
            let carthageLinkType: CarthageLinkType = (jsonDictionary.json(atKeyPath: "linkType") as String?).flatMap(CarthageLinkType.init(rawValue:)) ?? .default
            type = .carthage(findFrameworks: findFrameworks, linkType: carthageLinkType)
            reference = carthage
        } else if let sdk: String = jsonDictionary.json(atKeyPath: "sdk") {
            let sdkRoot: String? = jsonDictionary.json(atKeyPath: "root")
            type = .sdk(root: sdkRoot)
            reference = sdk
        } else if let package: String = jsonDictionary.json(atKeyPath: "package") {
            let product: String? = jsonDictionary.json(atKeyPath: "product")
            type = .package(product: product)
            reference = package
        } else if let bundle: String = jsonDictionary.json(atKeyPath: "bundle") {
            type = .bundle
            reference = bundle
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
        if let bool: Bool = jsonDictionary.json(atKeyPath: "weak") {
            weakLink = bool
        }
    }
}

extension Dependency: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "embed": embed,
            "codeSign": codeSign,
            "link": link,
        ]

        if removeHeaders != Dependency.removeHeadersDefault {
            dict["removeHeaders"] = removeHeaders
        }
        if implicit != Dependency.implicitDefault {
            dict["implicit"] = implicit
        }
        if weakLink != Dependency.weakLinkDefault {
            dict["weak"] = weakLink
        }

        switch type {
        case .target:
            dict["target"] = reference
        case .framework:
            dict["framework"] = reference
        case .carthage(let findFrameworks, let linkType):
            dict["carthage"] = reference
            if let findFrameworks = findFrameworks {
                dict["findFrameworks"] = findFrameworks
            }
            dict["linkType"] = linkType.rawValue
        case .sdk:
            dict["sdk"] = reference
        case .package:
            dict["package"] = reference
        case .bundle:
            dict["bundle"] = reference
        }

        return dict
    }
}

extension Dependency: PathContainer {

    static var pathProperties: [PathProperty] {
        [
            .string("framework"),
        ]
    }
}
