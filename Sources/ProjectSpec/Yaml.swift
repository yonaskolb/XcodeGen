import Foundation
import PathKit
import Yams

public func loadYamlDictionary(path: Path) throws -> [String: Any] {
    let data = try path.read()
    if data.isEmpty {
        return [:]
    }
    return try loadYamlDictionary(from: data)
}

func loadYamlDictionary(from data: Data) throws -> [String: Any] {
    guard let string = String(data: data, encoding: .utf8) else {
        return [:]
    }
    let resolver = Resolver.default
        .removing(.null) // remove rule so that empty quotes are treated as empty strings

    guard let yaml = try Yams.load(yaml: string, resolver) else {
        return [:]
    }
    return yaml as? [String: Any] ?? [:]
}

public func dumpYamlDictionary(_ dictionary: [String: Any], path: Path) throws {
    let string: String = try Yams.dump(object: dictionary)
    try path.write(string)
}
