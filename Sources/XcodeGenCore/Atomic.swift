//
//  Atomic.swift
//  
//
//  Created by Vladislav Lisianskii on 23.02.2022.
//

import Foundation

@propertyWrapper
public final class Atomic<Value> {

    private var value: Value

    private let queue = DispatchQueue(
        label: "com.xcodegencore.atomic.\(UUID().uuidString)",
        qos: .utility,
        attributes: .concurrent,
        autoreleaseFrequency: .inherit,
        target: .global()
    )

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            queue.sync { value }
        }
        set {
            queue.async(flags: .barrier) { [weak self] in
                self?.value = newValue
            }
        }
    }

    /// Allows us to get the actual `Atomic` instance with the $
    /// prefix.
    public var projectedValue: Atomic<Value> {
        return self
    }

    /// Modifies the protected value using `closure`.
    public func with<R>(
        _ closure: (inout Value) throws -> R
    ) rethrows -> R {
        try queue.sync(flags: .barrier) {
            try closure(&value)
        }
    }
}
