//
//  DarwinProcessExecutor.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/14.
//

#if canImport(Darwin)
import Foundation

/// Darwin-specific process executor using readabilityHandler
final class DarwinProcessExecutor: ProcessExecutorProtocol, @unchecked Sendable {
    
    func execute(
        executable: String,
        arguments: [String],
        input: Data?,
        timeout: TimeInterval?,
        workingDirectory: String?
    ) async throws -> ProcessResult {
        
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.standardInput = inputPipe
            
            // Set working directory if provided
            if let workingDir = workingDirectory {
                process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
            }
            
            // Thread-safe data accumulators
            let outputData = ThreadSafeData()
            let errorData = ThreadSafeData()
            let hasResumed = ThreadSafeFlag()
            
            @Sendable func safeResume(_ result: Result<ProcessResult, Error>) {
                guard !hasResumed.getAndSet(true) else { return }
                continuation.resume(with: result)
            }
            
            // Set up output handlers using readabilityHandler
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    outputData.append(data)
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    errorData.append(data)
                }
            }
            
            // Termination handler
            process.terminationHandler = { process in
                // Clean up handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // Read any remaining data
                let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                outputData.append(remainingOutput)
                errorData.append(remainingError)
                
                let result = ProcessResult(
                    exitCode: process.terminationStatus,
                    output: outputData.get(),
                    error: errorData.get()
                )
                
                safeResume(.success(result))
            }
            
            // Set up timeout if specified
            var timeoutWorkItem: DispatchWorkItem?
            if let timeout = timeout {
                let workItem = DispatchWorkItem {
                    if process.isRunning {
                        process.terminate()
                        safeResume(.failure(ProcessingError.timeout(duration: timeout)))
                    }
                }
                timeoutWorkItem = workItem
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: workItem)
            }
            
            do {
                try process.run()
                
                // Write input if provided
                if let input = input {
                    try? inputPipe.fileHandleForWriting.write(contentsOf: input)
                }
                try? inputPipe.fileHandleForWriting.close()
                
            } catch {
                timeoutWorkItem?.cancel()
                safeResume(.failure(error))
            }
        }
    }
}

/// Thread-safe data accumulator
private final class ThreadSafeData: @unchecked Sendable {
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

/// Thread-safe boolean flag
private final class ThreadSafeFlag: @unchecked Sendable {
    private var value = false
    private let lock = NSLock()
    
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

#endif

