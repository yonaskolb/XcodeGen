import Foundation
import JSONUtilities
import XcodeProj

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

    public enum DependencyType: Equatable {
        case target
        case framework
        case carthage(findFrameworks: Bool?)
        case swiftpm(config: XCRemoteSwiftPackageReference?)
        case sdk(root: String?)
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
            type = .carthage(findFrameworks: findFrameworks)
            reference = carthage
        } else if let sdk: String = jsonDictionary.json(atKeyPath: "sdk") {
            let sdkRoot: String? = jsonDictionary.json(atKeyPath: "root")
            type = .sdk(root: sdkRoot)
            reference = sdk
        } else if let swiftpm: String = jsonDictionary.json(atKeyPath: "swiftpm") {

            let versionRequirement: XCRemoteSwiftPackageReference.VersionRequirement? = {
                let versionRequirement: [String: Any]? = jsonDictionary.json(atKeyPath: "versionRequirement")
                if let versionRequirement = versionRequirement {
                    let jsonData = try! JSONSerialization.data(withJSONObject: versionRequirement, options: [])
                    return try! JSONDecoder().decode(XCRemoteSwiftPackageReference.VersionRequirement.self, from: jsonData)
                } else {
                    return nil
                }
            }()

            let repositoryURL: String? = jsonDictionary.json(atKeyPath: "repositoryURL")
            let config: XCRemoteSwiftPackageReference? = XCRemoteSwiftPackageReference(
                repositoryURL: repositoryURL ?? "",
                versionRequirement: versionRequirement
            )

            type = .swiftpm(config: config)
            reference = swiftpm
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
            "link": link
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
        case .carthage(let findFrameworks):
            dict["carthage"] = reference
            if let findFrameworks = findFrameworks {
                dict["findFrameworks"] = findFrameworks
            }
        case .swiftpm(let config):
            if let config = config {
                let swiftPMDict: [String: Any] = [
                    "repositoryURL": config.repositoryURL,
                    "requirements": config.versionRequirement?.json ?? [:]
                ]

                dict["swiftpm"] = swiftPMDict
            }
        case .sdk:
            dict["sdk"] = reference
        }

        return dict
    }
}

extension XCRemoteSwiftPackageReference.VersionRequirement {
    var json: [String: Any] {
        switch self {
        case let .revision(revision):
            return [
                "kind": "revision",
                "revision": revision,
            ]
        case let .branch(branch):
            return [
                "kind": "branch",
                "branch": branch,
            ]
        case let .exact(version):
            return [
                "kind": "exactVersion",
                "version": version,
            ]
        case let .range(from, to):
            return [
                "kind": "versionRange",
                "minimumVersion": from,
                "maximumVersion": to,
            ]
        case let .upToNextMinorVersion(version):
            return [
                "kind": "upToNextMinorVersion",
                "minimumVersion": version,
            ]
        case let .upToNextMajorVersion(version):
            return [
                "kind": "upToNextMajorVersion",
                "minimumVersion": version,
            ]
        }
    }
}

extension Dependency: PathContainer {

    static var pathProperties: [PathProperty] {
        return [
            .string("framework"),
        ]
    }
}
