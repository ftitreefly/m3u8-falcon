//
//  DIConfiguration.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

/// Configuration settings for dependency injection and service behavior
/// 
/// This struct contains all configurable parameters that affect the behavior
/// of the M3U8 utility services, including external tool paths, network settings,
/// and performance parameters.
/// 
/// ## Usage Example
/// ```swift
/// let config = DIConfiguration(
///     ffmpegPath: "/usr/local/bin/ffmpeg",
///     defaultHeaders: ["Authorization": "Bearer token"],
///     maxConcurrentDownloads: 10,
///     downloadTimeout: 120
/// )
/// 
/// // Use performance-optimized configuration
/// let optimizedConfig = DIConfiguration.performanceOptimized()
/// ```
public struct DIConfiguration: Sendable {
    /// Path to the FFmpeg executable for video processing
    public let ffmpegPath: String?
    
    /// Default HTTP headers to include in all requests
    public let defaultHeaders: [String: String]
    
    /// Maximum number of concurrent downloads allowed
    public let maxConcurrentDownloads: Int
    
    /// Timeout in seconds for download operations
    public let downloadTimeout: TimeInterval
    
    /// Resource timeout in seconds for overall transfer operations
    public let resourceTimeout: TimeInterval
    
    /// Maximum automatic retry attempts for transient network failures
    public let retryAttempts: Int
    
    /// Base backoff (seconds) used for exponential retry delays
    public let retryBackoffBase: TimeInterval
    
    /// Minimum log level for the logger
    public let logLevel: LogLevel
    
    /// Custom AES-128 decryption key (hex string or base64, optional)
    /// When provided, overrides the key URL in the M3U8 playlist
    public let key: String?
    
    /// Custom AES-128 initialization vector (hex string, optional)
    /// When provided, overrides the IV in the M3U8 playlist
    public let iv: String?
    
    /// Initializes a new configuration instance
    /// 
    /// - Parameters:
    ///   - ffmpegPath: Path to FFmpeg executable (optional, auto-detected if not provided)
    ///   - defaultHeaders: Default HTTP headers (defaults to standard browser headers)
    ///   - maxConcurrentDownloads: Maximum concurrent downloads (default: 16)
    ///   - downloadTimeout: Per-request timeout in seconds (default: 300)
    ///   - resourceTimeout: Overall resource timeout in seconds (default: equals downloadTimeout)
    ///   - retryAttempts: Max automatic retry attempts for transient failures (default: 0)
    ///   - retryBackoffBase: Base seconds for exponential backoff (default: 0.5)
    ///   - logLevel: Minimum log level for logger (default: .info)
    ///   - key: Custom AES-128 decryption key (optional)
    ///   - iv: Custom AES-128 initialization vector (optional)
    public init(
        ffmpegPath: String? = nil,
        defaultHeaders: [String: String] = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"],
        maxConcurrentDownloads: Int = 16,
        downloadTimeout: TimeInterval = 300,
        resourceTimeout: TimeInterval? = nil,
        retryAttempts: Int = 0,
        retryBackoffBase: TimeInterval = 0.5,
        logLevel: LogLevel = .info,
        key: String? = nil,
        iv: String? = nil
    ) {
        self.ffmpegPath = ffmpegPath
        self.defaultHeaders = defaultHeaders
        self.maxConcurrentDownloads = maxConcurrentDownloads
        self.downloadTimeout = downloadTimeout
        self.resourceTimeout = resourceTimeout ?? downloadTimeout
        self.retryAttempts = max(0, retryAttempts)
        self.retryBackoffBase = max(0, retryBackoffBase)
        self.logLevel = logLevel
        self.key = key
        self.iv = iv
    }
}

// MARK: - Configuration Extensions

extension DIConfiguration {
    /// Creates a performance-optimized configuration
    /// 
    /// This method returns a pre-configured instance optimized for high-performance
    /// M3U8 processing with auto-detected tool paths and optimized network settings.
    /// 
    /// ## Configuration Details
    /// - **FFmpeg**: Auto-detected from common installation locations
    /// - **Network**: Uses native URLSession (no external dependencies)
    /// - **Concurrent Downloads**: 20 (high concurrency)
    /// - **Timeout**: 60 seconds (balanced for performance)
    /// - **Headers**: Comprehensive browser-like headers
    /// 
    /// ## FFmpeg Detection Order
    /// 1. `/opt/homebrew/bin/ffmpeg` (Apple Silicon Homebrew)
    /// 2. `/usr/local/bin/ffmpeg` (Intel Homebrew / Manual installation)
    /// 3. `/usr/bin/ffmpeg` (System installation / Linux)
    /// 4. `PATH` environment variable lookup
    /// 5. `nil` if not found (will error when needed)
    /// 
    /// - Returns: A performance-optimized configuration instance
    /// 
    /// ## Usage Example
    /// ```swift
    /// // Use the performance-optimized configuration
    /// let config = DIConfiguration.performanceOptimized()
    /// 
    /// // Configure the dependency container
    /// let container = DependencyContainer()
    /// container.configurePerformanceOptimized(with: config)
    /// ```
    public static func performanceOptimized() -> DIConfiguration {
        return DIConfiguration(
            ffmpegPath: detectFFmpegPath(),
            defaultHeaders: [
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                "Accept": "*/*",
                "Accept-Language": "en-US,en;q=0.9",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive"
            ],
            maxConcurrentDownloads: 20,
            downloadTimeout: 60,
            resourceTimeout: 120,
            retryAttempts: 2,
            retryBackoffBase: 0.4,
            logLevel: .error
        )
    }
    
    /// Detects the FFmpeg installation path
    /// 
    /// This method searches common installation locations and the system PATH
    /// to find the FFmpeg executable. It returns the first valid path found.
    /// 
    /// ## Search Order
    /// 1. Homebrew on Apple Silicon: `/opt/homebrew/bin/ffmpeg`
    /// 2. Homebrew on Intel Mac: `/usr/local/bin/ffmpeg`
    /// 3. System installation: `/usr/bin/ffmpeg`
    /// 4. PATH environment lookup
    /// 
    /// - Returns: The path to FFmpeg if found, otherwise `nil`
    private static func detectFFmpegPath() -> String? {
        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",      // Apple Silicon Homebrew
            "/usr/local/bin/ffmpeg",         // Intel Homebrew / Manual
            "/usr/bin/ffmpeg",               // System / Linux
        ]
        
        // Check common paths first (faster)
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try PATH lookup
        return findInPath(executable: "ffmpeg")
    }
    
    /// Finds an executable in the system PATH
    /// 
    /// This method uses the `which` command to locate an executable
    /// in the system PATH environment variable.
    /// 
    /// - Parameter executable: The name of the executable to find
    /// - Returns: The full path to the executable if found, otherwise `nil`
    private static func findInPath(executable: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [executable]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return nil
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        } catch {
            return nil
        }
    }
}
