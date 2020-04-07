import Foundation
import JSONUtilities
import PathKit
import Yams

extension Dictionary where Key: JSONKey {
    public func json<T: NamedJSONDictionaryConvertible>(atKeyPath keyPath: JSONUtilities.KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove, parallel: Bool = false) throws -> [T] {
        guard let dictionary = json(atKeyPath: keyPath) as JSONDictionary? else {
            return []
        }
        if parallel {
            let defaultError = NSError(domain: "Unspecified error", code: 0, userInfo: nil)
            var itemResults: [Result<T, Error>] = Array(repeating: .failure(defaultError), count: dictionary.count)
            var ops: [BlockOperation] = []
            var idx: Int = 0
            for (key, _) in dictionary {
                ops.append(BlockOperation { [idx] in
                    do {
                        let jsonDictionary: JSONDictionary = try dictionary.json(atKeyPath: .key(key))
                        let item = try T(name: key, jsonDictionary: jsonDictionary)
                        itemResults[idx] = .success(item)
                    } catch {
                        itemResults[idx] = .failure(error)
                    }
                })
                idx += 1
            }
            let queue = OperationQueue()
            queue.qualityOfService = .userInteractive
            queue.maxConcurrentOperationCount = 8
            queue.addOperations(ops, waitUntilFinished: true)
            var items = ContiguousArray<T>()
            items.reserveCapacity(itemResults.count)
            for result in itemResults {
                switch result {
                case .failure(let error):
                    throw error
                case .success(let item):
                    items.append(item)
                }
            }
            return Array(items)
        } else {
            var items: [T] = []
            for (key, _) in dictionary {
                let jsonDictionary: JSONDictionary = try dictionary.json(atKeyPath: .key(key))
                let item = try T(name: key, jsonDictionary: jsonDictionary)
                items.append(item)
            }
            return items
        }
    }

    public func json<T: NamedJSONConvertible>(atKeyPath keyPath: JSONUtilities.KeyPath, invalidItemBehaviour: InvalidItemBehaviour<T> = .remove) throws -> [T] {
        guard let dictionary = json(atKeyPath: keyPath) as JSONDictionary? else {
            return []
        }
        var items: [T] = []
        for (key, value) in dictionary {
            let item = try T(name: key, json: value)
            items.append(item)
        }
        return items
    }
}

public protocol NamedJSONDictionaryConvertible {

    init(name: String, jsonDictionary: JSONDictionary) throws
}

public protocol NamedJSONConvertible {

    init(name: String, json: Any) throws
}

extension JSONObjectConvertible {

    public init(path: Path) throws {
        let content: String = try path.read()
        if content == "" {
            try self.init(jsonDictionary: [:])
            return
        }
        let yaml = try Yams.load(yaml: content)
        guard let jsonDictionary = yaml as? JSONDictionary else {
            throw JSONUtilsError.fileNotAJSONDictionary
        }
        try self.init(jsonDictionary: jsonDictionary)
    }
}
