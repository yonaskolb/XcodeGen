import Foundation
import PathKit
import Yams

public func loadYamlDictionary(path: Path) throws -> [String: Any] {
    let string: String = try path.read()
    return try loadYamlDictionary(contents: string)
}

public func loadYamlDictionary(contents: String) throws -> [String: Any] {
    if contents.isEmpty {
        return [:]
    }

    let resolver = Resolver.default
        .removing(.null) // remove rule so that empty quotes are treated as empty strings

    guard let yaml = try Yams.load(yaml: contents, resolver) else {
        return [:]
    }
    return yaml as? [String: Any] ?? [:]
}

public func loadOrderedTargetNames(path: Path) throws -> [String] {
    let string: String = try path.read()
    return try loadOrderedTargetNames(contents: string)
}

public func loadOrderedTargetNames(contents: String) throws -> [String] {
    guard !contents.isEmpty else { return [] }
    guard let node = try Yams.compose(yaml: contents),
          let rootMapping = node.mapping,
          let targetsNode = rootMapping["targets"],
          let targetsMapping = targetsNode.mapping else {
        return []
    }
    return targetsMapping.compactMap { key, _ in key.string }
}

public func dumpYamlDictionary(_ dictionary: [String: Any], path: Path) throws {
    let uncluttered = (dictionary as [String: Any?]).removingEmptyArraysDictionariesAndNils()
    let string: String = try Yams.dump(object: uncluttered)
    try path.write(string)
}
