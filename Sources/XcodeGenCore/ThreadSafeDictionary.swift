//
//  ThreadSafeDictionary.swift
//  
//
//  Created by Vladislav Lisianskii on 26.03.2022.
//

import Foundation

public final class ThreadSafeDictionary<Key: Hashable, Value>: CustomDebugStringConvertible {

    public typealias StorageType = [Key: Value]

    private var storage: StorageType

    private let queue = DispatchQueue(
        label: "com.xcodegencore.atomicDict.\(UUID().uuidString)",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit,
        target: .global()
    )

    public init(_ initialValue: StorageType = [:]) {
        storage = initialValue
    }

    public subscript(key: Key) -> Value? {
        get { queue.sync { storage[key] }}
        set { queue.async(flags: .barrier) { [weak self] in self?.storage[key] = newValue } }
    }

    public var debugDescription: String {
        return storage.debugDescription
    }

    public func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }
}

extension ThreadSafeDictionary: Equatable where Value: Equatable {
    public static func ==(lhs: ThreadSafeDictionary, rhs: ThreadSafeDictionary) -> Bool {
        lhs.storage == rhs.storage
    }
}
