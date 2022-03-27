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
            queue.sync {
                _value
            }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?._value = newValue
            }
        }
    }
}

// MARK: - Equatable
extension ThreadSafeContainer: Equatable where Value: Equatable {
    public static func ==(lhs: ThreadSafeContainer, rhs: ThreadSafeContainer) -> Bool {
        lhs.value == rhs.value
    }
}
