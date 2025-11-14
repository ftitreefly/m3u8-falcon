//
//  LinuxProcessExecutor.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/14.
//

#if !canImport(Darwin)
import Foundation
import Dispatch

/// Linux-specific process executor using continuous polling
final class LinuxProcessExecutor: ProcessExecutorProtocol, @unchecked Sendable {
    
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
            let processRunning = ThreadSafeFlag()
            let hasResumed = ThreadSafeFlag()
            
            @Sendable func safeResume(_ result: Result<ProcessResult, Error>) {
                guard !hasResumed.getAndSet(true) else { return }
                continuation.resume(with: result)
            }
            
            // Set up continuous pipe readers for Linux
            let readGroup = DispatchGroup()
            
            func drainPipe(_ handle: FileHandle, into storage: ThreadSafeData) {
                readGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    defer { readGroup.leave() }
                    
                    var consecutiveEmptyReads = 0
                    let maxEmptyReads = 10
                    
                    while processRunning.get() || consecutiveEmptyReads < maxEmptyReads {
                        do {
                            if let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
                                storage.append(chunk)
                                consecutiveEmptyReads = 0
                            } else {
                                if !processRunning.get() {
                                    // Process finished, read remaining data
                                    if let finalChunk = try? handle.readToEnd(), !finalChunk.isEmpty {
                                        storage.append(finalChunk)
                                    }
                                    break
                                }
                                consecutiveEmptyReads += 1
                                Thread.sleep(forTimeInterval: 0.01)
                            }
                        } catch {
                            // Error reading, try to get remaining data
                            if let finalChunk = try? handle.readToEnd(), !finalChunk.isEmpty {
                                storage.append(finalChunk)
                            }
                            break
                        }
                    }
                }
            }
            
            processRunning.set(true)
            drainPipe(outputPipe.fileHandleForReading, into: outputData)
            drainPipe(errorPipe.fileHandleForReading, into: errorData)
            
            // Termination handler
            process.terminationHandler = { process in
                // Signal that process has terminated
                processRunning.set(false)
                
                // Wait for pipe readers to finish
                readGroup.wait()
                
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
                processRunning.set(false)
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

