//
//  PlatformAbstractions.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/14.
//


import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Process Execution Abstraction

/// Protocol for executing external processes with output capture
/// 
/// This protocol provides a platform-agnostic interface for executing external
/// commands and processes. Implementations handle platform-specific differences
/// in process output capture and management.
/// 
/// ## Platform Implementations
/// - **Darwin** (macOS/iOS): Uses `readabilityHandler` for efficient async output capture
/// - **Linux**: Uses polling-based output capture with thread-safe buffers
/// 
/// ## Usage Example
/// ```swift
/// let executor: ProcessExecutorProtocol = // ... get from DI
/// let result = try await executor.execute(
///     executable: "/usr/bin/ffmpeg",
///     arguments: ["-version"],
///     input: nil,
///     timeout: 30.0,
///     workingDirectory: nil
/// )
/// print("FFmpeg version: \(result.outputString)")
/// ```
/// 
/// ## Thread Safety
/// All implementations are thread-safe and conform to `Sendable`, making them
/// safe to use in concurrent contexts.
public protocol ProcessExecutorProtocol: Sendable {
    /// Executes an external command and captures its output
    /// 
    /// This method spawns a new process, executes the command with the given
    /// arguments, and captures both standard output and standard error streams.
    /// 
    /// - Parameters:
    ///   - executable: Full path to the executable to run (e.g., "/usr/bin/ffmpeg")
    ///   - arguments: Array of command-line arguments to pass to the executable
    ///   - input: Optional data to write to the process's standard input
    ///   - timeout: Optional timeout in seconds. If exceeded, the process is terminated
    ///   - workingDirectory: Optional working directory for the process. If nil, uses current directory
    /// 
    /// - Returns: A `ProcessResult` containing the exit code, captured output, and error streams
    /// 
    /// - Throws:
    ///   - `ProcessingError.timeout` if the process exceeds the timeout
    ///   - `ProcessingError.invalidCommand` if the executable cannot be found
    ///   - `ProcessingError.platformError` for other platform-specific errors
    /// 
    /// ## Notes
    /// - The method waits for the process to complete before returning
    /// - Both stdout and stderr are captured separately
    /// - If a timeout is specified, the process will be terminated if it exceeds that time
    func execute(
        executable: String,
        arguments: [String],
        input: Data?,
        timeout: TimeInterval?,
        workingDirectory: String?
    ) async throws -> ProcessResult
}

/// Encapsulates the result of an external process execution
/// 
/// This struct provides convenient access to the process output, error streams,
/// and exit code. It includes helper properties for string conversion and
/// success checking.
/// 
/// ## Usage Example
/// ```swift
/// let result = try await executor.execute(...)
/// 
/// if result.isSuccess {
///     print("Command succeeded: \(result.outputString)")
/// } else {
///     print("Command failed with code \(result.exitCode)")
///     print("Error: \(result.errorString)")
/// }
/// ```
public struct ProcessResult: Sendable {
    /// The process exit code (0 indicates success)
    public let exitCode: Int32
    
    /// Raw output data from standard output (stdout)
    public let output: Data
    
    /// Raw error data from standard error (stderr)
    public let error: Data
    
    /// Standard output decoded as UTF-8 string
    /// 
    /// Returns an empty string if the output cannot be decoded as UTF-8.
    public var outputString: String {
        String(data: output, encoding: .utf8) ?? ""
    }
    
    /// Standard error decoded as UTF-8 string
    /// 
    /// Returns an empty string if the error output cannot be decoded as UTF-8.
    public var errorString: String {
        String(data: error, encoding: .utf8) ?? ""
    }
    
    /// Indicates whether the process completed successfully
    /// 
    /// Returns `true` if the exit code is 0, `false` otherwise.
    public var isSuccess: Bool {
        exitCode == 0
    }
    
    /// Creates a new process result
    /// 
    /// - Parameters:
    ///   - exitCode: The process exit code
    ///   - output: Raw stdout data
    ///   - error: Raw stderr data
    public init(exitCode: Int32, output: Data, error: Data) {
        self.exitCode = exitCode
        self.output = output
        self.error = error
    }
}

// MARK: - Streaming Network Abstraction

/// Protocol for memory-efficient streaming network downloads
/// 
/// This protocol provides a platform-agnostic interface for downloading content
/// as a stream of bytes, enabling memory-efficient processing of large files.
/// 
/// ## Platform Implementations
/// - **Darwin** (macOS/iOS): Uses `URLSession.bytes(from:)` for native async streaming
/// - **Linux**: Uses `URLSessionDataDelegate` with manual byte streaming
/// 
/// ## Usage Example
/// ```swift
/// let client: StreamingNetworkClientProtocol = // ... get from DI
/// let (response, byteStream) = try await client.fetchAsyncBytes(from: videoURL)
/// 
/// guard let httpResponse = response as? HTTPURLResponse, 
///       httpResponse.statusCode == 200 else {
///     throw NetworkError.invalidResponse(videoURL.absoluteString)
/// }
/// 
/// var downloadedBytes = 0
/// for try await byte in byteStream {
///     // Process each byte
///     downloadedBytes += 1
/// }
/// print("Downloaded \(downloadedBytes) bytes")
/// ```
/// 
/// ## Memory Efficiency
/// Unlike traditional download methods that load the entire file into memory,
/// this protocol enables processing data as it arrives, making it ideal for
/// large video files and bandwidth-constrained environments.
/// 
/// ## Thread Safety
/// All implementations are thread-safe and conform to `Sendable`.
public protocol StreamingNetworkClientProtocol: Sendable {
    /// Fetches content from a URL as an asynchronous byte stream
    /// 
    /// This method initiates a network request and returns both the response
    /// metadata and an async stream of bytes for processing the content.
    /// 
    /// - Parameter url: The URL to fetch content from
    /// 
    /// - Returns: A tuple containing:
    ///   - `URLResponse`: Response metadata (status code, headers, etc.)
    ///   - `AsyncThrowingStream<UInt8, Error>`: Stream of bytes as they arrive
    /// 
    /// - Throws:
    ///   - `NetworkError.connectionFailed` if the connection fails
    ///   - `NetworkError.timeout` if the request times out
    ///   - `NetworkError.serverError` for HTTP 5xx errors
    ///   - `NetworkError.clientError` for HTTP 4xx errors
    /// 
    /// ## Notes
    /// - The byte stream begins producing data as soon as the response headers arrive
    /// - The stream may throw errors during iteration if the connection is interrupted
    /// - It's the caller's responsibility to handle errors in the stream
    func fetchAsyncBytes(from url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>)
}

// MARK: - Platform Detection

/// Utility enum for platform detection and information
/// 
/// Provides compile-time and runtime utilities for detecting the current
/// platform and adapting behavior accordingly.
/// 
/// ## Usage Example
/// ```swift
/// if PlatformUtils.isDarwin {
///     print("Running on \(PlatformUtils.platformName)")
///     // Use Darwin-specific optimizations
/// } else if PlatformUtils.isLinux {
///     // Use Linux-specific implementations
/// }
/// ```
enum PlatformUtils {
    /// Indicates if running on a Darwin-based operating system
    /// 
    /// Returns `true` for macOS, iOS, watchOS, tvOS, and visionOS.
    /// This is determined at compile time.
    static var isDarwin: Bool {
        #if canImport(Darwin)
        return true
        #else
        return false
        #endif
    }
    
    /// Indicates if running on Linux
    /// 
    /// Returns `true` only for Linux platforms.
    /// This is determined at compile time.
    static var isLinux: Bool {
        #if os(Linux)
        return true
        #else
        return false
        #endif
    }
    
    /// Returns the name of the current platform
    /// 
    /// Possible return values:
    /// - "macOS" for macOS
    /// - "iOS" for iOS
    /// - "Linux" for Linux
    /// - "Windows" for Windows
    /// - "Unknown" for other platforms
    /// 
    /// This is determined at compile time.
    static var platformName: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return "iOS"
        #elseif os(Linux)
        return "Linux"
        #elseif os(Windows)
        return "Windows"
        #else
        return "Unknown"
        #endif
    }
}

#if canImport(Darwin)
typealias DefaultProcessExecutor = DarwinProcessExecutor
typealias DefaultStreamingNetworkClient = DarwinStreamingNetworkClient

func makeDefaultStreamingNetworkClient(
    configuration: URLSessionConfiguration
) -> StreamingNetworkClientProtocol {
    return DefaultStreamingNetworkClient(configuration: configuration)
}
#else
typealias DefaultProcessExecutor = LinuxProcessExecutor
typealias DefaultStreamingNetworkClient = LinuxStreamingNetworkClient

func makeDefaultStreamingNetworkClient(
    configuration: URLSessionConfiguration
) -> StreamingNetworkClientProtocol {
    return DefaultStreamingNetworkClient(configuration: configuration)
}
#endif

