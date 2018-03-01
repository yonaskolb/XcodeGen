import Foundation
import PathKit
import Yams

public func loadYamlDictionary(path: Path) throws -> [String: Any] {
    let string: String = try path.read()
    if string == "" {
        return [:]
    }

    // just treat true and false as Bools
    let boolRule = try! Resolver.Rule(.bool, "^(?:true|false)$")

    let resolver = Resolver.default
        .removing(.null) // remove rule so that empty quotes are treated as empty strings
        .removing(.bool) // remove rule so that strings like YES aren't parsed as bools
        .appending(boolRule)

    guard let yaml = try Yams.load(yaml: string, resolver) else {
        return [:]
    }
    return yaml as? [String: Any] ?? [:]
}
