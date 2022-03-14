//
//  Atomic.swift
//  
//
//  Created by Vladislav Lisianskii on 23.02.2022.
//

import Foundation

@propertyWrapper
struct Atomic<Value> {
    private let queue = DispatchQueue(label: "com.xcodegencore.atomic")
    private var value: Value

    init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    var wrappedValue: Value {
        get {
            return queue.sync { value }
        }
        set {
            queue.sync { value = newValue }
        }
    }
}
