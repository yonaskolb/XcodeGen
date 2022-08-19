import Foundation
import JSONUtilities

public struct TestableTargetReference: Hashable {
    public var name: String
    public var location: Location
    
    public var targetReference: TargetReference {
        switch location {
        case .local:
            return TargetReference(name: name, location: .local)
        case .project(let projectName):
            return TargetReference(name: name, location: .project(projectName))
        case .package:
            fatalError("Package target is only available for testable")
        }
    }

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

extension TestableTargetReference {
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

    public static func local(_ name: String) -> TestableTargetReference {
        TestableTargetReference(name: name, location: .local)
    }

    public static func project(_ name: String) -> TestableTargetReference {
        let paths = name.split(separator: "/")
        return TestableTargetReference(name: String(paths[1]), location: .project(String(paths[0])))
    }

    public static func package(_ name: String) -> TestableTargetReference {
        let paths = name.split(separator: "/")
        return TestableTargetReference(name: String(paths[1]), location: .package(String(paths[0])))
    }
}

extension TestableTargetReference: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        try! self.init(value)
    }
}

extension TestableTargetReference: CustomStringConvertible {
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

extension TestableTargetReference: JSONObjectConvertible {

    public init(jsonDictionary: JSONDictionary) throws {
        if let project: String = jsonDictionary.json(atKeyPath: "project") {
            let paths = project.split(separator: "/")
            name = String(paths[1])
            location = .project(String(paths[0]))
        } else if let project: String = jsonDictionary.json(atKeyPath: "package") {
            let paths = project.split(separator: "/")
            name = String(paths[1])
            location = .package(String(paths[0]))
        } else {
            name = try jsonDictionary.json(atKeyPath: "local")
            location = .local
        }
    }
}

extension TestableTargetReference: JSONEncodable {
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
