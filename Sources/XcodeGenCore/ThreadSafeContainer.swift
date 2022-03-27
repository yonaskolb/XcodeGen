//
//  ThreadSafeContainer.swift
//  
//
//  Created by Vladislav Lisianskii on 26.03.2022.
//

import Foundation

public final class ThreadSafeContainer<Value> {

    private var _value: Value

    private let queue = DispatchQueue(
        label: "com.xcodegencore.threadSafeContainer.\(UUID().uuidString)",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit,
        target: .global()
    )

    public init(_ initialValue: Value) {
        _value = initialValue
    }

    public var value: Value {
        get {
            reader { $0 }
        }
        set {
            writer { $0 = newValue }
        }
    }
}

// MARK: - Private methods
extension ThreadSafeContainer {
    private func reader<U>(_ closure: (Value) -> U) -> U {
        queue.sync {
            closure(_value)
        }
    }

    private func writer(_ closure: @escaping (inout Value) -> Void) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            closure(&self._value)
        }
    }
}

// MARK: - Equatable
extension ThreadSafeContainer: Equatable where Value: Equatable {
    public static func ==(lhs: ThreadSafeContainer, rhs: ThreadSafeContainer) -> Bool {
        lhs.value == rhs.value
    }
}
