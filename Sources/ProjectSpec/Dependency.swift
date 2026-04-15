import Foundation
import JSONUtilities

public struct Dependency: Equatable {
    public static let removeHeadersDefault = true
    public static let implicitDefault = false
    public static let weakLinkDefault = false
    public static let excludeFromTransitiveLinkingDefault = false
    public static let platformFilterDefault: PlatformFilter = .all

    public var type: DependencyType
    public var reference: String
    public var embed: Bool?
    public var codeSign: Bool?
    public var removeHeaders: Bool = removeHeadersDefault
    public var link: Bool?
    public var implicit: Bool = implicitDefault
    public var weakLink: Bool = weakLinkDefault
    public var excludeFromTransitiveLinking: Bool = excludeFromTransitiveLinkingDefault
    public var platformFilter: PlatformFilter = platformFilterDefault
    public var destinationFilters: [SupportedDestination]?
    public var platforms: Set<Platform>?
    public var copyPhase: BuildPhaseSpec.CopyFilesSettings?

    public init(
        type: DependencyType,
        reference: String,
        embed: Bool? = nil,
        codeSign: Bool? = nil,
        link: Bool? = nil,
        implicit: Bool = implicitDefault,
        weakLink: Bool = weakLinkDefault,
        excludeFromTransitiveLinking: Bool = excludeFromTransitiveLinkingDefault,
        platformFilter: PlatformFilter = platformFilterDefault,
        destinationFilters: [SupportedDestination]? = nil,
        platforms: Set<Platform>? = nil,
        copyPhase: BuildPhaseSpec.CopyFilesSettings? = nil
    ) {
        self.type = type
        self.reference = reference
        self.embed = embed
        self.codeSign = codeSign
        self.link = link
        self.implicit = implicit
        self.weakLink = weakLink
        self.excludeFromTransitiveLinking = excludeFromTransitiveLinking
        self.platformFilter = platformFilter
        self.destinationFilters = destinationFilters
        self.platforms = platforms
        self.copyPhase = copyPhase
    }
    
    public enum PlatformFilter: String, Equatable {
        case all
        case iOS
        case macOS
    }
    
    public enum CarthageLinkType: String {
        case dynamic
        case `static`

        public static let `default` = dynamic
    }

    public enum DependencyType: Hashable {
        case target
        case framework
        case carthage(findFrameworks: Bool?, linkType: CarthageLinkType)
        case sdk(root: String?)
        case package(products: [String])
        case bundle
    }
}

extension Dependency {
    public var uniqueID: String {
        switch type {
        case .package(let products):
            if !products.isEmpty {
                return "\(reference)/\(products.joined(separator: ","))"
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
        hasher.combine(type)
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
            if let products: [String] = jsonDictionary.json(atKeyPath: "products") {
                type = .package(products: products)
                reference = package
            } else if let product: String = jsonDictionary.json(atKeyPath: "product") {
                type = .package(products: [product])
                reference = package
            } else {
                type = .package(products: [])
                reference = package
            }
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
        if let bool: Bool = jsonDictionary.json(atKeyPath: "excludeFromTransitiveLinking") {
            excludeFromTransitiveLinking = bool
        }

        if let platformFilterString: String = jsonDictionary.json(atKeyPath: "platformFilter"), let platformFilter = PlatformFilter(rawValue: platformFilterString) {
            self.platformFilter = platformFilter
        } else {
            self.platformFilter = .all
        }

        if let destinationFilters: [SupportedDestination] = jsonDictionary.json(atKeyPath: "destinationFilters") {
            self.destinationFilters = destinationFilters
        }
        
        if let platforms: [ProjectSpec.Platform] = jsonDictionary.json(atKeyPath: "platforms") {
            self.platforms = Set(platforms)
        }

        if let object: JSONDictionary = jsonDictionary.json(atKeyPath: "copy") {
            copyPhase = try BuildPhaseSpec.CopyFilesSettings(jsonDictionary: object)
        }
    }
}

extension Dependency: JSONEncodable {
    public func toJSONValue() -> Any {
        var dict: [String: Any?] = [
            "embed": embed,
            "codeSign": codeSign,
            "link": link,
            "platforms": platforms?.map(\.rawValue).sorted(),
            "copy": copyPhase?.toJSONValue(),
            "destinationFilters": destinationFilters?.map { $0.rawValue },
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
        if excludeFromTransitiveLinking != Dependency.excludeFromTransitiveLinkingDefault {
            dict["excludeFromTransitiveLinking"] = excludeFromTransitiveLinking
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
