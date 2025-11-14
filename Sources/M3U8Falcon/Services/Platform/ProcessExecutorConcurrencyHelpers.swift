//
//  ProcessExecutorConcurrencyHelpers.swift
//  M3U8Falcon
//
//  Shared thread-safe utilities for process executors.
//

import Foundation
import Atomics

/// Thread-safe data accumulator shared by process executors
final class ThreadSafeData: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()
    
    func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(newData)
    }
    
    func get() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

/// Thread-safe boolean flag utility shared by process executors
final class ThreadSafeFlag: @unchecked Sendable {
    private let value: ManagedAtomic<Bool>
    
    init(initialValue: Bool = false) {
        self.value = ManagedAtomic(initialValue)
    }
    
    func set(_ newValue: Bool) {
        value.store(newValue, ordering: .sequentiallyConsistent)
    }
    
    func get() -> Bool {
        value.load(ordering: .sequentiallyConsistent)
    }
    
    /// Atomically gets the current value and sets a new value
    func getAndSet(_ newValue: Bool) -> Bool {
        value.exchange(newValue, ordering: .sequentiallyConsistent)
    }
}


