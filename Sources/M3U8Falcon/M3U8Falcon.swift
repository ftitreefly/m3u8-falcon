//
//  M3U8Falcon.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Public API

/// The main public interface for M3U8Falcon with modern error handling and dependency injection
/// 
/// This struct provides a high-level API for downloading and processing M3U8 video files.
/// It uses dependency injection for better testability and modularity.
/// 
/// ## Usage Example
/// ```swift
/// // Initialize the utility
/// await M3U8Falcon.initialize()
/// 
/// // Download an M3U8 file
/// try await M3U8Falcon.download(
///     .web,
///     url: URL(string: "https://example.com/video.m3u8")!,
    ///     savedDirectory: URL(fileURLWithPath: "/path/to/save"),
///     name: "my-video"
    /// )
/// 
/// // Parse an M3U8 file
/// let result = try await M3U8Falcon.parse(
///     url: URL(string: "https://example.com/video.m3u8")!
/// )
/// ```
public struct M3U8Falcon {
    
    /// Initializes the dependency injection container with default services
    /// 
    /// **This method must be called before using `download()` or `parse()` methods.**
    /// It configures the dependency injection container with the appropriate services.
    /// 
    /// - Parameter configuration: Custom configuration for dependency injection. 
    ///   If not provided, uses performance-optimized configuration by default.
    ///   The logger is automatically configured based on `configuration.logLevel`.
    /// - Note: Safe to call multiple times; subsequent calls reconfigure services.
    /// 
    /// ## Usage Example
    /// ```swift
    /// // Use default configuration
    /// await M3U8Falcon.initialize()
    /// 
    /// // Use custom configuration with verbose logging
    /// let config = DIConfiguration(
    ///     maxConcurrentDownloads: 10,
    ///     logLevel: .verbose
    /// )
    /// await M3U8Falcon.initialize(with: config)
    /// ```
    @MainActor public static func initialize(with configuration: DIConfiguration = DIConfiguration.performanceOptimized()) async {
        await GlobalDependencies.shared.configure(with: configuration)
        Logger.debug("Concurrent file downloads count: \(configuration.maxConcurrentDownloads), single file download timeout: \(configuration.downloadTimeout) seconds", category: .download)
    }
    
    /// Downloads M3U8 content from a URL and processes it using dependency injection
    /// 
    /// This method downloads an M3U8 playlist file and all its associated video segments,
    /// saving them to the specified directory. It supports both web and local file sources.
    /// 
    /// - Parameters:
    ///   - method: The download method to use (`.web` for HTTP/HTTPS, `.local` for local files)
    ///   - url: The URL to download from (must be a valid M3U8 playlist URL)
    ///   - savedDirectory: Directory to save the downloaded content. Defaults to user's Downloads folder
    ///   - name: Optional name for the output file. If not provided, uses the original filename
    ///   - strategy: Optional decryption strategy for encrypted segments. If `nil`, defaults to `.normal` (no decryption).
    ///     Use `.customAES128(key:iv:)` for AES-128 encrypted streams with custom key/IV.
    ///   - verbose: Whether to output detailed operation-specific information (progress, etc.). 
    ///     Note: Global logger verbosity is set in `initialize()`, this only affects operation-specific output.
    /// - Precondition: `initialize()` must be called before calling this method.
    /// - Precondition: When `method == .web`, network connectivity is required.
    /// - Precondition: When `method == .local`, `url` must point to a readable local `.m3u8` file.
    /// 
    /// - Throws: 
    ///   - `ConfigurationError.notInitialized()` if `initialize()` has not been called
    ///   - `FileSystemError.failedToCreateDirectory` if directory creation fails
    ///   - `NetworkError` if network requests fail
    ///   - `ParsingError` if M3U8 parsing fails
    ///   - `ProcessingError` if task creation fails
    /// 
    /// ## Usage Example
    /// ```swift
    /// // Initialize first (required)
    /// await M3U8Falcon.initialize()
    /// 
    /// // Then download (savedDirectory is optional, defaults to Downloads folder)
    /// try await M3U8Falcon.download(
    ///     .web,
    ///     url: URL(string: "https://example.com/video.m3u8")!,
    ///     name: "my-video",
    ///     verbose: true
    /// )
    /// 
    /// // Download with custom AES-128 decryption
    /// try await M3U8Falcon.download(
    ///     .web,
    ///     url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    ///     name: "encrypted-video",
    ///     strategy: .customAES128(
    ///         key: "0123456789abcdef0123456789abcdef",
    ///         iv: "0123456789abcdef0123456789abcdef"
    ///     )
    /// )
    /// 
    /// // Or specify a custom directory
    /// try await M3U8Falcon.download(
    ///     .web,
    ///     url: URL(string: "https://example.com/video.m3u8")!,
    ///     savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    ///     name: "my-video"
    /// )
    /// ```
    public static func download(
        _ method: Method = .web,
        url: URL,
        savedDirectory: URL? = nil,
        name: String? = nil,
        strategy: DecryptionStrategy? = nil,
        verbose: Bool = false
    ) async throws {
        guard await GlobalDependencies.shared.isConfigured() else {
            throw ConfigurationError.notInitialized()
        }
        
        let resolvedDirectory = try await resolvedDirectory(savedDirectory)
        
        let baseUrl = method.baseURL ?? url.deletingLastPathComponent()

        // Use provided strategy or default to .normal
        let decryptionStrategy = strategy ?? .normal

        let request = TaskRequest(
            url: url,
            baseUrl: baseUrl,
            savedDirectory: resolvedDirectory,
            fileName: name,
            method: method,
            verbose: verbose,
            decryptionStrategy: decryptionStrategy
        )

        let taskManager = try await GlobalDependencies.shared.resolve(TaskManagerProtocol.self)
        try await taskManager.createTask(request)
    }
    
    /// Parses an M3U8 file and returns the parsed result using dependency injection
    /// 
    /// This method downloads and parses an M3U8 playlist file, returning a structured
    /// representation of the playlist content. It supports both web URLs and local files.
    /// 
    /// - Parameters:
    ///   - url: The URL of the M3U8 file to parse
    ///   - method: The parsing method to use (`.web` for HTTP/HTTPS, `.local` for local files)
    /// - Precondition: `initialize()` must be called before calling this method.
    /// - Precondition: When `method == .local`, `url` must be a readable file URL.
    /// 
    /// - Returns: A `M3U8Parser.ParserResult` containing the parsed playlist data
    /// 
    /// - Throws: 
    ///   - `ConfigurationError.notInitialized()` if `initialize()` has not been called
    ///   - `ParsingError` if the M3U8 content cannot be parsed
    ///   - `NetworkError` if network requests fail
    ///   - `FileSystemError.failedToReadFromFile` if local file reading fails
    /// 
    /// ## Usage Example
    /// ```swift
    /// // Initialize first (required)
    /// await M3U8Falcon.initialize()
    /// 
    /// // Parse from web URL
    /// let result = try await M3U8Falcon.parse(
    ///     url: URL(string: "https://example.com/video.m3u8")!
    /// )
    /// 
    /// switch result {
    /// case .master(let masterPlaylist):
    ///     print("Master playlist with \(masterPlaylist.tags.streamTags.count) streams")
    /// case .media(let mediaPlaylist):
    ///     print("Media playlist with \(mediaPlaylist.tags.mediaSegments.count) segments")
    /// case .cancelled:
    ///     print("Parsing was cancelled")
    /// }
    /// 
    /// // Parse local file
    /// let localResult = try await M3U8Falcon.parse(
    ///     url: URL(fileURLWithPath: "/path/to/local/playlist.m3u8"),
    ///     method: .local
    /// )
    /// ```
    public static func parse(
        url: URL,
        method: Method = .web
    ) async throws -> M3U8Parser.ParserResult {
        guard await GlobalDependencies.shared.isConfigured() else {
            throw ConfigurationError.notInitialized()
        }
        let downloader = try await GlobalDependencies.shared.resolve(M3U8DownloaderProtocol.self)
        let parser = try await GlobalDependencies.shared.resolve(M3U8ParserServiceProtocol.self)
        let fileSystem = try await GlobalDependencies.shared.resolve(FileSystemServiceProtocol.self)
        
        do {
            let baseURL: URL
            
            if case .local = method {
                let localFileContent = try fileSystem.content(at: url)
                baseURL = url.deletingLastPathComponent()
                return try parser.parseContent(localFileContent, baseURL: baseURL, type: .media)
            } else {
                let content = try await downloader.downloadContent(from: url)
                baseURL = method.baseURL ?? url.deletingLastPathComponent()
                return try parser.parseContent(content, baseURL: baseURL, type: .media)
            }
        } catch let error as ParsingError {
            // Re-throw ParsingError as-is to preserve error details
            throw error
        } catch {
            // Wrap other errors in ParsingError for consistent error handling
            throw ParsingError(
                code: 2999,
                underlyingError: error,
                message: "Failed to parse M3U8 file",
                context: "URL: \(url.absoluteString)"
            )
        }
    }
    
    /// Resolves the final directory (provided or default) and ensures it exists
    /// 
    /// - Parameter savedDirectory: Optional directory path. If `nil`, uses the default Downloads directory.
    /// - Returns: The resolved directory URL that is guaranteed to exist
    /// - Throws: `FileSystemError.failedToCreateDirectory` if directory creation fails
    private static func resolvedDirectory(_ savedDirectory: URL?) async throws -> URL {
        let directory: URL
        if let savedDirectory = savedDirectory {
            directory = savedDirectory
        } else {
            directory = try await GlobalDependencies.shared.resolve(PathProviderProtocol.self).downloadsDirectory()
        }
        
        let fileSystem = try await GlobalDependencies.shared.resolve(FileSystemServiceProtocol.self)
        
        // Check if directory already exists
        // Note: fileExists returns true for both files and directories, but createDirectory
        // will fail if a file exists at this path, which will be caught and rethrown below
        guard !fileSystem.fileExists(at: directory) else {
            return directory
        }
        
        do {
            try fileSystem.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw FileSystemError.failedToCreateDirectory(directory.path)
        }
        
        return directory
    }
}
