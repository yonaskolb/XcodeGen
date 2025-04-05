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
            let keys = Array(dictionary.keys)
            var itemResults: [Result<T, Error>] = Array(repeating: .failure(defaultError), count: keys.count)
            itemResults.withUnsafeMutableBufferPointer { buffer in
                let bufferWrapper = BufferWrapper(buffer: buffer)
                DispatchQueue.concurrentPerform(iterations: dictionary.count) { idx in
                    do {
                        let key = keys[idx]
                        let jsonDictionary: JSONDictionary = try dictionary.json(atKeyPath: .key(key))
                        let item = try T(name: key, jsonDictionary: jsonDictionary)
                        bufferWrapper.buffer[idx] = .success(item)
                    } catch {
                        bufferWrapper.buffer[idx] = .failure(error)
                    }
                }
            }
            return try itemResults.map { try $0.get() }
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

private final class BufferWrapper<T>: @unchecked Sendable {
    var buffer: UnsafeMutableBufferPointer<T>

    init(buffer: UnsafeMutableBufferPointer<T>) {
        self.buffer = buffer
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
