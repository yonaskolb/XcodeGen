import Foundation
import XcodeProj
import JSONUtilities
import Version

public enum SwiftPackage: Equatable {

    public typealias VersionRequirement = XCRemoteSwiftPackageReference.VersionRequirement

    case remote(url: String, versionRequirement: VersionRequirement)
    case local(path: String)

    public var isLocal: Bool {
        if case .local = self {
            return true
        }
        return false
    }
}

extension SwiftPackage: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let path: String = jsonDictionary.json(atKeyPath: "path") {
            self = .local(path: path)
        } else {
            let versionRequirement: VersionRequirement = try VersionRequirement(jsonDictionary: jsonDictionary)
            try Self.validateVersion(versionRequirement: versionRequirement)
            self = .remote(url: try jsonDictionary.json(atKeyPath: "url"), versionRequirement: versionRequirement)
        }
    }

    private static func validateVersion(versionRequirement: VersionRequirement) throws {
        switch versionRequirement {

        case .upToNextMajorVersion(let version):
            try _ = Version.parse(version)

        case .upToNextMinorVersion(let version):
            try _ = Version.parse(version)

        case .range(let from, let to):
            try _ = Version.parse(from)
            try _ = Version.parse(to)

        case .exact(let version):
            try _ = Version.parse(version)

        default:
            break
        }
    }
}

extension SwiftPackage: JSONEncodable {

    public func toJSONValue() -> Any {
        var dictionary: JSONDictionary = [:]
        switch self {
        case .remote(let url, let versionRequirement):
            dictionary["url"] = url

            switch versionRequirement {

            case .upToNextMajorVersion(let version):
                dictionary["majorVersion"] = version
            case .upToNextMinorVersion(let version):
                dictionary["minorVersion"] = version
            case .range(let from, let to):
                dictionary["minVersion"] = from
                dictionary["maxVersion"] = to
            case .exact(let version):
                dictionary["exactVersion"] = version
            case .branch(let branch):
                dictionary["branch"] = branch
            case .revision(let revision):
                dictionary["revision"] = revision
            }
            return dictionary
        case .local(let path):
            dictionary["path"] = path
        }

        return dictionary
    }
}

extension SwiftPackage.VersionRequirement: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["exactVersion"] != nil {
            self = try .exact(jsonDictionary.json(atKeyPath: "exactVersion"))
        } else if jsonDictionary["version"] != nil {
            self = try .exact(jsonDictionary.json(atKeyPath: "version"))
        } else if jsonDictionary["revision"] != nil {
            self = try .revision(jsonDictionary.json(atKeyPath: "revision"))
        } else if jsonDictionary["branch"] != nil {
            self = try .branch(jsonDictionary.json(atKeyPath: "branch"))
        } else if jsonDictionary["minVersion"] != nil && jsonDictionary["maxVersion"] != nil {
            let minimum: String = try jsonDictionary.json(atKeyPath: "minVersion")
            let maximum: String = try jsonDictionary.json(atKeyPath: "maxVersion")
            self = .range(from: minimum, to: maximum)
        } else if jsonDictionary["minorVersion"] != nil {
            self = try .upToNextMinorVersion(jsonDictionary.json(atKeyPath: "minorVersion"))
        } else if jsonDictionary["majorVersion"] != nil {
            self = try .upToNextMajorVersion(jsonDictionary.json(atKeyPath: "majorVersion"))
        } else if jsonDictionary["from"] != nil {
            self = try .upToNextMajorVersion(jsonDictionary.json(atKeyPath: "from"))
        } else {
            throw SpecParsingError.unknownPackageRequirement(jsonDictionary)
        }
    }
}
