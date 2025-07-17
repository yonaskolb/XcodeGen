import Foundation
import XcodeProj
import JSONUtilities
import Version

public enum SwiftPackage: Equatable {

    public typealias VersionRequirement = XCRemoteSwiftPackageReference.VersionRequirement

    static let githubPrefix = "https://github.com/"

    case remote(url: String, versionRequirement: VersionRequirement)
    case local(path: String, group: String?, excludeFromProject: Bool)

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
            let customLocation: String? = jsonDictionary.json(atKeyPath: "group")
            let excludeFromProject: Bool = jsonDictionary.json(atKeyPath: "excludeFromProject") ?? false
            self = .local(path: path, group: customLocation, excludeFromProject: excludeFromProject)
        } else {
            let versionRequirement: VersionRequirement = try VersionRequirement(jsonDictionary: jsonDictionary)
            try Self.validateVersion(versionRequirement: versionRequirement)
            let url: String
            if jsonDictionary["github"] != nil {
                let github: String = try jsonDictionary.json(atKeyPath: "github")
                url = "\(Self.githubPrefix)\(github)"
            } else {
                url = try jsonDictionary.json(atKeyPath: "url")
            }
            self = .remote(url: url, versionRequirement: versionRequirement)
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
            if url.hasPrefix(Self.githubPrefix) {
                dictionary["github"] = url.replacingOccurrences(of: Self.githubPrefix, with: "")
            } else {
                dictionary["url"] = url
            }

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
        case let .local(path, group, excludeFromProject):
            dictionary["path"] = path
            dictionary["group"] = group
            dictionary["excludeFromProject"] = excludeFromProject
        }

        return dictionary
    }
}

extension SwiftPackage.VersionRequirement: JSONUtilities.JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if jsonDictionary["exactVersion"] != nil {
            do {
                let exactVersion: String = try jsonDictionary.json(atKeyPath: "exactVersion")
                self = .exact(exactVersion)
            } catch {
                let exactVersion: Double = try jsonDictionary.json(atKeyPath: "exactVersion")
                self = .exact(String(exactVersion))
            }
        } else if jsonDictionary["version"] != nil {
            do {
                let version: String = try jsonDictionary.json(atKeyPath: "version")
                self = .exact(version)
            } catch {
                let version: Double = try jsonDictionary.json(atKeyPath: "version")
                self = .exact(String(version))
            }
        } else if jsonDictionary["revision"] != nil {
            do {
                let revision: String = try jsonDictionary.json(atKeyPath: "revision")
                self = .exact(revision)
            } catch {
                let revision: Double = try jsonDictionary.json(atKeyPath: "revision")
                self = .exact(String(revision))
            }
        } else if jsonDictionary["branch"] != nil {
            do {
                let branch: String = try jsonDictionary.json(atKeyPath: "branch")
                self = .exact(branch)
            } catch {
                let branch: Double = try jsonDictionary.json(atKeyPath: "branch")
                self = .exact(String(branch))
            }
        } else if jsonDictionary["minVersion"] != nil && jsonDictionary["maxVersion"] != nil {
            let minimum: String = try jsonDictionary.json(atKeyPath: "minVersion")
            let maximum: String = try jsonDictionary.json(atKeyPath: "maxVersion")
            self = .range(from: minimum, to: maximum)
        } else if jsonDictionary["minorVersion"] != nil {
            do {
                let minorVersion: String = try jsonDictionary.json(atKeyPath: "minorVersion")
                self = .exact(minorVersion)
            } catch {
                let minorVersion: Double = try jsonDictionary.json(atKeyPath: "minorVersion")
                self = .exact(String(minorVersion))
            }
        } else if jsonDictionary["majorVersion"] != nil {
            do {
                let majorVersion: String = try jsonDictionary.json(atKeyPath: "majorVersion")
                self = .exact(majorVersion)
            } catch {
                let majorVersion: Double = try jsonDictionary.json(atKeyPath: "majorVersion")
                self = .exact(String(majorVersion))
            }
        } else if jsonDictionary["from"] != nil {
            do {
                let from: String = try jsonDictionary.json(atKeyPath: "from")
                self = .exact(from)
            } catch {
                let from: Double = try jsonDictionary.json(atKeyPath: "from")
                self = .exact(String(from))
            }
        } else {
            throw SpecParsingError.unknownPackageRequirement(jsonDictionary)
        }
    }
}

extension SwiftPackage: PathContainer {
    static var pathProperties: [PathProperty] {
        [
            .dictionary([
                .string("path"),
            ]),
        ]
    }
}
