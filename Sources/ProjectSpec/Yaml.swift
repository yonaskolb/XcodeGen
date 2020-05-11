import Foundation
import PathKit
import Yams

public func loadYamlDictionary(path: Path) throws -> [String: Any] {
    let string: String = try path.read()
    if string == "" {
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
    let uncluttered = (dictionary as [String: Any?]).removingEmptyArraysDictionariesAndNils()
    let string: String = try Yams.dump(object: uncluttered)
    try path.write(string)
}
