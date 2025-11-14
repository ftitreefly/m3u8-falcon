//
//  DefaultCommandExecutor.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Default Command Executor

/// Default implementation of command execution for external tools
/// 
/// This executor provides a robust implementation for running external commands
/// like FFmpeg. It delegates platform-specific execution to ProcessExecutorProtocol.
/// 
/// ## Features
/// - Platform-abstracted command execution
/// - Automatic platform selection (Darwin/Linux)
/// - Working directory support
/// - Comprehensive error reporting
/// 
/// ## Usage Example
/// ```swift
/// let executor = DefaultCommandExecutor()
/// 
/// // Execute FFmpeg command
/// let output = try await executor.execute(
///     command: "/usr/local/bin/ffmpeg",
///     arguments: ["-i", "input.mp4", "-c", "copy", "output.mp4"],
///     workingDirectory: "/path/to/working/dir"
/// )
/// ```
public struct DefaultCommandExecutor: CommandExecutorProtocol {
  /// Platform-specific process executor
  private let processExecutor: ProcessExecutorProtocol
  
  /// Initializes a new command executor
  /// - Parameter processExecutor: Platform-specific executor (auto-selected if nil)
  public init(processExecutor: ProcessExecutorProtocol? = nil) {
    if let executor = processExecutor {
      self.processExecutor = executor
    } else {
      // Auto-select based on platform
      #if canImport(Darwin)
      self.processExecutor = DarwinProcessExecutor()
      #else
      self.processExecutor = LinuxProcessExecutor()
      #endif
    }
  }
  
  /// Executes a shell command with arguments
  /// 
  /// This method delegates to the platform-specific process executor.
  /// 
  /// - Parameters:
  ///   - command: The full path to the executable
  ///   - arguments: Array of command-line arguments
  ///   - workingDirectory: Optional working directory for the command
  /// 
  /// - Returns: The command output as a string
  /// 
  /// - Throws: 
  ///   - `CommandExecutionError.processError` if the process fails
  /// 
  /// ## Usage Example
  /// ```swift
  /// let output = try await executor.execute(
  ///     command: "/usr/local/bin/ffmpeg",
  ///     arguments: ["-version"],
  ///     workingDirectory: nil
  /// )
  /// print("FFmpeg version: \(output)")
  /// ```
  public func execute(command: String, arguments: [String], workingDirectory: String?) async throws -> String {
    do {
      let result = try await processExecutor.execute(
        executable: command,
        arguments: arguments,
        input: nil,
        timeout: nil,
        workingDirectory: workingDirectory
      )
      
      guard result.isSuccess else {
        throw ProcessingError.fromCommandResult(result, command: command)
      }
      
      return result.outputString
      
    } catch let error as ProcessingError {
      // Re-throw ProcessingError as-is
      throw error
    } catch {
      // Wrap other errors
      throw ProcessingError.platformError(
        underlying: error,
        context: "command execution"
      )
    }
  }
}


// MARK: - Default Network Client

public struct DefaultNetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let defaultHeaders: [String: String]
    private let retryAttempts: Int
    private let retryBackoffBase: TimeInterval
    
    public init(configuration: DIConfiguration) {
        let cfg = URLSessionConfiguration.default
        #if canImport(Darwin)
        cfg.waitsForConnectivity = true
        #endif
        cfg.httpMaximumConnectionsPerHost = max(6, configuration.maxConcurrentDownloads)
        cfg.timeoutIntervalForRequest = configuration.downloadTimeout
        cfg.timeoutIntervalForResource = configuration.resourceTimeout
        cfg.httpAdditionalHeaders = configuration.defaultHeaders
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: cfg)
        self.defaultHeaders = configuration.defaultHeaders
        self.retryAttempts = configuration.retryAttempts
        self.retryBackoffBase = configuration.retryBackoffBase
    }
    
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request
        for (key, value) in defaultHeaders where req.value(forHTTPHeaderField: key) == nil {
            req.setValue(value, forHTTPHeaderField: key)
        }
        var lastError: Error?
        for attempt in 0...retryAttempts {
            do {
                return try await session.data(for: req)
            } catch {
                lastError = error
                if attempt < retryAttempts {
                    let delay = retryBackoffBase * pow(2, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw error
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}
