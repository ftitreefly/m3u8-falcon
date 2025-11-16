//
//  ProcessExecutorConcurrencyHelpers.swift
//  M3U8Falcon
//
//  Shared thread-safe utilities for process executors.
//

import Foundation

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
    private var value: Bool
    private let lock = NSLock()
    
    init(initialValue: Bool = false) {
        self.value = initialValue
    }
    
    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
    
    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    
    /// Atomically gets the current value and sets a new value
    func getAndSet(_ newValue: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let oldValue = value
        value = newValue
        return oldValue
    }
}


