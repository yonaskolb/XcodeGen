import Foundation
import JSONUtilities

public struct TargetReference: Hashable {
    public var name: String
    public var location: Location

    public enum Location: Hashable {
        case local
        case project(String)
        case package(String)
    }

    public init(name: String, location: Location) {
        self.name = name
        self.location = location
    }
}

extension TargetReference {
    public init(_ string: String) throws {
        let paths = string.split(separator: "/")
        switch paths.count {
        case 2:
            location = .project(String(paths[0]))
            name = String(paths[1])
        case 1:
            location = .local
            name = String(paths[0])
        default:
            throw SpecParsingError.invalidTargetReference(string)
        }
    }

    public static func local(_ name: String) -> TargetReference {
        TargetReference(name: name, location: .local)
    }
}

extension TargetReference: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        try! self.init(value)
    }
}

extension TargetReference: CustomStringConvertible {
    public var reference: String {
        switch location {
        case .local: return name
        case .project(let root), .package(let root):
            return "\(root)/\(name)"
        }
    }

    public var description: String {
        reference
    }
}

extension TargetReference: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let project: String = jsonDictionary.json(atKeyPath: "project") {
            let paths = project.split(separator: "/")
            name = String(paths[1])
            location = .project(String(paths[0]))
        } else {
            name = try jsonDictionary.json(atKeyPath: "local")
            location = .local
        }
    }
}

extension TargetReference: JSONEncodable {
    public func toJSONValue() -> Any {
        var dictionary: JSONDictionary = [:]
        switch self.location {
        case .package(let packageName):
            dictionary["package"] = "\(packageName)/\(name)"
        case .project(let projectName):
            dictionary["project"] = "\(projectName)/\(name)"
        case .local:
            dictionary["local"] = name
        }
        return dictionary
    }
}
