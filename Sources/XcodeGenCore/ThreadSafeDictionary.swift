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
        get { reader { $0[key] } }
        set { writer { $0[key] = newValue } }
    }

    public var debugDescription: String {
        return storage.debugDescription
    }

    public func removeAll() {
        writer { $0.removeAll() }
    }
}

// MARK: - Private methods
extension ThreadSafeDictionary {
    private func reader<U>(_ closure: (StorageType) -> U) -> U {
        queue.sync {
            closure(storage)
        }
    }

    private func writer(_ closure: @escaping (inout StorageType) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            closure(&self.storage)
        }
    }
}

// MARK: - Equatable
extension ThreadSafeDictionary: Equatable where Value: Equatable {
    public static func ==(lhs: ThreadSafeDictionary, rhs: ThreadSafeDictionary) -> Bool {
        lhs.storage == rhs.storage
    }
}
