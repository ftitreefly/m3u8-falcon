//
//  ServiceProtocols.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/9.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Service Protocols

/// Protocol for downloading M3U8 content from various sources
/// 
/// This protocol defines the interface for downloading M3U8 playlist files and
/// their associated video segments. Implementations should handle both HTTP/HTTPS
/// and local file access with proper error handling and retry logic.
/// 
/// ## Usage Example
/// ```swift
/// class MyDownloader: M3U8DownloaderProtocol {
///     func downloadContent(from url: URL) async throws -> String {
///         let data = try await downloadRawData(from: url)
///         return String(data: data, encoding: .utf8) ?? ""
///     }
///     
///     func downloadRawData(from url: URL) async throws -> Data {
///         // Implementation for downloading raw data
///     }
///     
///     func downloadSegments(at urls: [URL], to directory: URL, headers: [String: String]) async throws {
///         // Implementation for downloading segments
///     }
/// }
/// ```
public protocol M3U8DownloaderProtocol: Sendable {
    /// Downloads M3U8 content from a URL and returns it as a string
    /// 
    /// This method downloads the content of an M3U8 playlist file and returns
    /// it as a UTF-8 encoded string for further processing.
    /// 
    /// - Parameter url: The URL of the M3U8 file to download
    /// 
    /// - Returns: The M3U8 content as a string
    /// 
    /// - Throws: 
    ///   - `NetworkError` if the network request fails
    ///   - `ProcessingError` if the content cannot be decoded
    func downloadContent(from url: URL) async throws -> String
    
    /// Downloads raw data from a URL
    /// 
    /// This method downloads the raw bytes from a URL, useful for binary files
    /// or when you need to handle the data format yourself.
    /// 
    /// - Parameter url: The URL to download from
    /// 
    /// - Returns: The raw data bytes
    /// 
    /// - Throws: `NetworkError` if the network request fails
    func downloadRawData(from url: URL) async throws -> Data
    
    /// Downloads multiple video segments concurrently
    /// 
    /// This method downloads multiple video segment files concurrently and saves
    /// them to the specified directory. It should handle retry logic and progress
    /// tracking for large downloads.
    /// 
    /// - Parameters:
    ///   - urls: Array of URLs for the video segments to download
    ///   - directory: The directory where segments should be saved
    ///   - headers: HTTP headers to include in the requests
    /// 
    /// - Throws: 
    ///   - `NetworkError` if any segment download fails
    ///   - `FileSystemError` if files cannot be saved
    func downloadSegments(at urls: [URL], to directory: URL, headers: [String: String]) async throws
}

/// Protocol for parsing M3U8 playlist content
/// 
/// This protocol defines the interface for parsing M3U8 playlist files and
/// extracting structured data from them. Implementations should handle both
/// master playlists and media playlists with proper error handling.
/// 
/// ## Usage Example
/// ```swift
/// class MyParser: M3U8ParserServiceProtocol {
///     func parseContent(_ content: String, baseURL: URL, type: PlaylistType) throws -> M3U8Parser.ParserResult {
///         let parser = M3U8Parser()
///         let params = M3U8ParserParams(
///             playlist: content,
///             baseUrl: baseURL,
///             playlistType: type
///         )
///         return try parser.parse(params: params)
///     }
/// }
/// ```
public protocol M3U8ParserServiceProtocol: Sendable {
    /// Parses M3U8 content and returns the structured result
    /// 
    /// This method parses M3U8 playlist content and returns a structured
    /// representation that can be used for further processing.
    /// 
    /// - Parameters:
    ///   - content: The M3U8 content as a string
    ///   - baseURL: The base URL for resolving relative URLs in the playlist
    ///   - type: The expected type of playlist (master, media, etc.)
    /// 
    /// - Returns: A structured representation of the parsed playlist
    /// 
    /// - Throws: 
    ///   - `ParsingError` if the content cannot be parsed
    ///   - `ProcessingError` if the playlist type is not supported
    func parseContent(_ content: String, baseURL: URL, type: PlaylistType) throws -> M3U8Parser.ParserResult
}

/// Protocol for video processing operations
/// 
/// This protocol defines the interface for video processing operations such as
/// combining video segments and decrypting encrypted content. Implementations
/// typically use external tools like FFmpeg for these operations.
/// 
/// ## Usage Example
/// ```swift
/// class MyProcessor: VideoProcessorProtocol {
///     func combineSegments(in directory: URL, outputFile: URL) async throws {
///         // Implementation using FFmpeg to combine segments
///     }
///     
///     func decryptSegment(at url: URL, to outputURL: URL, keyURL: URL?) async throws {
///         // Implementation for decrypting segments
///     }
/// }
/// ```
public protocol VideoProcessorProtocol: Sendable {
    /// Combines multiple video segments into a single output file
    /// 
    /// This method finds all video segment files in the specified directory
    /// and combines them into a single video file using external tools.
    /// 
    /// - Parameters:
    ///   - directory: The directory containing the video segments
    ///   - outputFile: The URL where the combined video file will be saved
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if no segments are found or combination fails
    ///   - `CommandExecutionError` if the external tool fails
    ///   - `FileSystemError` if file operations fail
    func combineSegments(in directory: URL, outputFile: URL) async throws
    
    /// Decrypts an encrypted video segment
    /// 
    /// This method decrypts an encrypted video segment using the provided
    /// decryption key and saves the decrypted content to the output location.
    /// 
    /// - Parameters:
    ///   - url: The URL of the encrypted segment file
    ///   - outputURL: The URL where the decrypted segment will be saved
    ///   - keyURL: Optional URL to the decryption key file
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if decryption fails
    ///   - `CommandExecutionError` if the external tool fails
    ///   - `FileSystemError` if file operations fail
    func decryptSegment(at url: URL, to outputURL: URL, keyURL: URL?) async throws

    /// Decrypts and combines video segments into a single output file
    /// 
    /// This method decrypts an encrypted video segment and saves it to the specified
    /// output location. It supports various encryption methods and automatically
    /// detects hardware acceleration capabilities.
    /// 
    /// - Parameters:
    ///   - directory: The directory containing the video segments
    ///   - localM3U8FileName: The name of the local M3U8 file
    ///   - outputFile: The URL where the combined video file will be saved
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if decryption fails
    ///   - `CommandExecutionError` if the external tool fails
    ///   - `FileSystemError` if file operations fail
    /// 
    /// ## Usage Example
    /// ```swift
    /// let segmentsDir = URL(fileURLWithPath: "/path/to/segments/")
    /// let localM3U8FileName = "file.m3u8"
    /// let outputVideo = URL(fileURLWithPath: "/path/to/output/video.mp4")
    /// 
    /// try await processor.decryptAndCombineSegments(in: segmentsDir, with: localM3U8FileName, outputFile: outputVideo) 
    /// ```
    func decryptAndCombineSegments(in directory: URL, with localM3U8FileName: String, outputFile: URL) async throws
}

/// Protocol for file system operations
/// 
/// This protocol defines the interface for file system operations such as
/// creating directories, checking file existence, and copying files. It provides
/// an abstraction layer for file system access.
/// 
/// ## Usage Example
/// ```swift
/// class MyFileSystem: FileSystemServiceProtocol {
///     func createDirectory(at path: String, withIntermediateDirectories: Bool) throws {
///         try FileManager.default.createDirectory(
///             atPath: path,
///             withIntermediateDirectories: withIntermediateDirectories
///         )
///     }
///     
///     func fileExists(at path: String) -> Bool {
///         return FileManager.default.fileExists(atPath: path)
///     }
///     
///     // ... other method implementations
/// }
/// ```
public protocol FileSystemServiceProtocol: Sendable {
    /// Creates a directory at the specified URL
    /// 
    /// - Parameters:
    ///   - url: The URL where the directory should be created
    ///   - withIntermediateDirectories: Whether to create intermediate directories
    /// 
    /// - Throws: `FileSystemError` if directory creation fails
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws
    
    /// Checks if a file exists at the given URL
    /// 
    /// - Parameter url: The URL to check
    /// 
    /// - Returns: `true` if the file exists, `false` otherwise
    func fileExists(at url: URL) -> Bool
    
    /// Removes a file or directory from the file system
    /// 
    /// - Parameter url: The URL of the file or directory to remove
    /// 
    /// - Throws: `FileSystemError` if removal fails
    func removeItem(at url: URL) throws
    
    /// Creates a temporary directory and returns its URL
    /// 
    /// - Parameter saltString: Optional string to make the directory name unique
    /// 
    /// - Returns: The URL of the created temporary directory
    /// 
    /// - Throws: `FileSystemError` if directory creation fails
    func createTemporaryDirectory(_ saltString: String?) throws -> URL
  
    /// Returns the content of a file as a string
    /// 
    /// - Parameter url: The URL of the file to read
    /// 
    /// - Returns: The file content as a string
    /// 
    /// - Throws: `FileSystemError` if the file cannot be read
    func content(at url: URL) throws -> String

    /// Returns the contents of a directory
    /// 
    /// - Parameter url: The URL of the directory to list
    /// 
    /// - Returns: Array of URLs for items in the directory
    /// 
    /// - Throws: `FileSystemError` if the directory cannot be accessed
    func contentsOfDirectory(at url: URL) throws -> [URL]

    /// Copies a file from one location to another
    /// 
    /// - Parameters:
    ///   - sourceURL: The URL of the source file
    ///   - destinationURL: The URL where the file should be copied
    /// 
    /// - Throws: `FileSystemError` if the copy operation fails
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws
}

/// Request parameters for creating a download task
/// 
/// This struct encapsulates all the parameters needed to create a download task,
/// providing a clean interface that avoids function parameter count violations.
/// 
/// ## Usage Example
/// ```swift
/// let request = TaskRequest(
///     url: URL(string: "https://example.com/video.m3u8")!,
///     baseUrl: nil,
///     savedDirectory: "/Users/username/Downloads/",
///     fileName: "my-video",
///     method: .web,
///     verbose: true,
///     key: "0123456789abcdef0123456789abcdef",
///     iv: "0123456789abcdef0123456789abcdef"
/// )
/// 
/// try await taskManager.createTask(request)
/// ```
public struct TaskRequest: Sendable {
    /// The URL of the M3U8 file to download
    public let url: URL
    
    /// Optional base URL for resolving relative URLs
    public let baseUrl: URL?
    
    /// Directory where the final video file will be saved
    public let savedDirectory: URL
    
    /// Optional custom filename for the output video
    public let fileName: String?
    
    /// The download method (web or local)
    public let method: Method
    
    /// Whether to output detailed information during the download process
    public let verbose: Bool
    
    /// Custom AES-128 decryption key (hex string, optional)
    /// When provided, overrides the key URL in the M3U8 playlist
    public let key: String?
    
    /// Custom AES-128 initialization vector (hex string, optional)
    /// When provided, overrides the IV in the M3U8 playlist
    public let iv: String?
    
    /// Initializes a new task request
    /// 
    /// - Parameters:
    ///   - url: The URL of the M3U8 file to download
    ///   - baseUrl: Optional base URL for resolving relative URLs
    ///   - savedDirectory: Directory where the final video file will be saved
    ///   - fileName: Optional custom filename for the output video
    ///   - method: The download method (web or local)
    ///   - verbose: Whether to output detailed information during the download process
    ///   - key: Custom AES-128 decryption key (optional)
    ///   - iv: Custom AES-128 initialization vector (optional)
    public init(
        url: URL,
        baseUrl: URL? = nil,
        savedDirectory: URL,
        fileName: String? = nil,
        method: Method,
        verbose: Bool = false,
        key: String? = nil,
        iv: String? = nil
    ) {
        self.url = url
        self.baseUrl = baseUrl
        self.savedDirectory = savedDirectory
        self.fileName = fileName
        self.method = method
        self.verbose = verbose
        self.key = key
        self.iv = iv
    }
}

/// Protocol for task management operations
/// 
/// This protocol defines the interface for managing download tasks, including
/// creating, monitoring, and cancelling tasks. It provides a high-level API
/// for coordinating complex download operations.
/// 
/// ## Usage Example
/// ```swift
/// class MyTaskManager: TaskManagerProtocol {
///     func createTask(_ request: TaskRequest) async throws {
///         // Implementation for creating and executing tasks
///     }
///     
///     func getTaskStatus(for taskId: String) async -> TaskStatus? {
///         // Implementation for getting task status
///     }
///     
///     func cancelTask(taskId: String) async throws {
///         // Implementation for cancelling tasks
///     }
/// }
/// ```
public protocol TaskManagerProtocol: Sendable {
    /// Creates and executes a download task
    /// 
    /// This method creates a new download task and executes it using the provided
    /// request parameters.
    /// 
    /// - Parameter request: The task request containing all necessary parameters
    /// 
    /// - Throws: Various errors depending on the failure scenario
    func createTask(_ request: TaskRequest) async throws
    
    /// Gets the current status of a task
    /// 
    /// - Parameter taskId: The unique identifier of the task
    /// 
    /// - Returns: The current status of the task, or `nil` if not found
    func getTaskStatus(for taskId: String) async -> TaskStatus?
    
    /// Cancels a running task
    /// 
    /// - Parameter taskId: The unique identifier of the task to cancel
    /// 
    /// - Throws: `ProcessingError` if the task is not found or cannot be cancelled
    func cancelTask(taskId: String) async throws
}

/// Protocol for external command execution
/// 
/// This protocol defines the interface for executing external shell commands,
/// typically used for running tools like FFmpeg for video processing.
/// 
/// ## Usage Example
/// ```swift
/// class MyCommandExecutor: CommandExecutorProtocol {
///     func execute(command: String, arguments: [String], workingDirectory: String?) async throws -> String {
///         let process = Process()
///         process.executableURL = URL(fileURLWithPath: command)
///         process.arguments = arguments
///         if let workingDirectory = workingDirectory {
///             process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
///         }
///         
///         let output = Pipe()
///         process.standardOutput = output
///         
///         try process.run()
///         process.waitUntilExit()
///         
///         let data = output.fileHandleForReading.readDataToEndOfFile()
///         return String(data: data, encoding: .utf8) ?? ""
///     }
/// }
/// ```
public protocol CommandExecutorProtocol: Sendable {
    /// Executes a shell command with arguments
    /// 
    /// This method executes an external command and returns its output as a string.
    /// 
    /// - Parameters:
    ///   - command: The command to execute (full path)
    ///   - arguments: Array of command-line arguments
    ///   - workingDirectory: Optional working directory for the command
    /// 
    /// - Returns: The command output as a string
    /// 
    /// - Throws: `CommandExecutionError` if the command fails to execute
    func execute(command: String, arguments: [String], workingDirectory: String?) async throws -> String
}

/// Protocol for extracting M3U8 links from web pages
/// 
/// This protocol defines the interface for extracting M3U8 playlist URLs from
/// web pages. It provides a unified way for third-party tools to extract
/// streaming links from various websites and platforms.
/// 
/// ## Usage Example
/// ```swift
/// class MyLinkExtractor: M3U8LinkExtractorProtocol {
///     func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
///         // Implementation for extracting M3U8 links from web page
///     }
///     
///     func getSupportedDomains() -> [String] {
///         return ["example.com", "video-site.com"]
///     }
///     
///     func getExtractorInfo() -> ExtractorInfo {
///         return ExtractorInfo(
///             name: "My Link Extractor",
///             version: "1.0.0",
///             supportedDomains: getSupportedDomains(),
///             capabilities: [.directLinks, .javascriptVariables, .apiEndpoints, .structuredData]
///         )
///     }
/// }
/// ```
public protocol M3U8LinkExtractorProtocol: Sendable {
    /// Extracts M3U8 links from a web page
    /// 
    /// This method analyzes a web page to find embedded M3U8 playlist URLs.
    /// It should handle various extraction methods including:
    /// - Direct M3U8 links in page source
    /// - JavaScript variables containing M3U8 URLs
    /// - API endpoints that return M3U8 playlists
    /// - Dynamic content loaded via AJAX
    /// 
    /// - Parameters:
    ///   - url: The URL of the web page to analyze
    ///   - options: Configuration options for the extraction process
    /// 
    /// - Returns: Array of found M3U8 links with metadata
    /// 
    /// - Throws: 
    ///   - `NetworkError` if the web page cannot be accessed
    ///   - `ParsingError` if the content cannot be parsed
    ///   - `ProcessingError` if no M3U8 links are found
    func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link]
    
    /// Returns a list of supported domains for this extractor
    /// 
    /// This method returns the list of domains that this extractor can handle.
    /// It helps in routing requests to the appropriate extractor implementation.
    /// 
    /// - Returns: Array of supported domain names (e.g., ["youtube.com", "vimeo.com"])
    func getSupportedDomains() -> [String]
    
    /// Returns complete information about this extractor
    /// 
    /// This method returns a complete ExtractorInfo struct containing
    /// all metadata about this extractor. This allows the extractor
    /// to provide accurate information about its capabilities and
    /// supported domains.
    /// 
    /// - Returns: Complete extractor information
    func getExtractorInfo() -> ExtractorInfo
    
    /// Checks if this extractor can handle the given URL
    /// 
    /// This method provides a quick way to determine if this extractor
    /// is suitable for processing the given URL.
    /// 
    /// - Parameter url: The URL to check
    /// 
    /// - Returns: `true` if this extractor can handle the URL, `false` otherwise
    func canHandle(url: URL) -> Bool
}

/// Protocol for managing multiple M3U8 link extractors
/// 
/// This protocol defines the interface for a registry that manages multiple
/// link extractors and routes requests to the appropriate extractor based
/// on the target URL.
/// 
/// ## Usage Example
/// ```swift
/// class MyExtractorRegistry: M3U8ExtractorRegistryProtocol {
///     func registerExtractor(_ extractor: M3U8LinkExtractorProtocol) {
///         // Implementation for registering extractors
///     }
///     
///     func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
///         // Implementation for routing to appropriate extractor
///     }
/// }
/// ```
public protocol M3U8ExtractorRegistryProtocol: Sendable {
    /// Registers a new link extractor
    /// 
    /// This method registers a link extractor that can handle specific domains
    /// or URL patterns. The registry will use this extractor for URLs that
    /// match its supported domains.
    /// 
    /// - Parameter extractor: The extractor to register
    func registerExtractor(_ extractor: M3U8LinkExtractorProtocol)

    /// Registers a new link extractor with priority (higher wins). Optional extension API.
    func registerExtractor(_ extractor: M3U8LinkExtractorProtocol, priority: Int)
    
    /// Extracts M3U8 links using the appropriate registered extractor
    /// 
    /// This method automatically selects the appropriate extractor based on
    /// the URL and delegates the extraction to it.
    /// 
    /// - Parameters:
    ///   - url: The URL of the web page to analyze
    ///   - options: Configuration options for the extraction process
    /// 
    /// - Returns: Array of found M3U8 links with metadata
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if no suitable extractor is found
    ///   - Various errors from the selected extractor
    func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link]
    
    /// Gets a list of all registered extractors
    /// 
    /// This method returns information about all registered extractors,
    /// useful for debugging and monitoring purposes.
    /// 
    /// - Returns: Array of extractor information
    func getRegisteredExtractors() -> [ExtractorInfo]
}

/// Protocol for web page content analysis
/// 
/// This protocol defines the interface for analyzing web page content to
/// extract various types of information, including M3U8 links, video metadata,
/// and other streaming-related data.
/// 
/// ## Usage Example
/// ```swift
/// class MyPageAnalyzer: WebPageAnalyzerProtocol {
///     func analyzePage(at url: URL, options: PageAnalysisOptions) async throws -> PageAnalysisResult {
///         // Implementation for analyzing web page content
///     }
/// }
/// ```
public protocol WebPageAnalyzerProtocol: Sendable {
    /// Analyzes a web page to extract streaming-related information
    /// 
    /// This method performs comprehensive analysis of a web page to find
    /// streaming content, including M3U8 playlists, video metadata, and
    /// other relevant information.
    /// 
    /// - Parameters:
    ///   - url: The URL of the web page to analyze
    ///   - options: Configuration options for the analysis
    /// 
    /// - Returns: Comprehensive analysis result with all found information
    /// 
    /// - Throws: 
    ///   - `NetworkError` if the page cannot be accessed
    ///   - `ParsingError` if the page content cannot be parsed
    func analyzePage(at url: URL, options: PageAnalysisOptions) async throws -> PageAnalysisResult
}

/// Protocol for handling dynamic content and JavaScript execution
/// 
/// This protocol defines the interface for executing JavaScript code and
/// handling dynamic content that may contain M3U8 links. It's particularly
/// useful for modern web applications that load content dynamically.
/// 
/// ## Usage Example
/// ```swift
/// class MyJavaScriptExecutor: JavaScriptExecutorProtocol {
///     func executeScript(_ script: String, in context: JavaScriptContext) async throws -> JavaScriptResult {
///         // Implementation for executing JavaScript
///     }
/// }
/// ```
public protocol JavaScriptExecutorProtocol: Sendable {
    /// Executes JavaScript code in a web page context
    /// 
    /// This method executes JavaScript code to extract information from
    /// dynamic web pages, such as M3U8 URLs stored in JavaScript variables
    /// or generated by client-side code.
    /// 
    /// - Parameters:
    ///   - script: The JavaScript code to execute
    ///   - context: The execution context (page URL, cookies, etc.)
    /// 
    /// - Returns: The result of JavaScript execution
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if JavaScript execution fails
    ///   - `ParsingError` if the result cannot be parsed
    func executeScript(_ script: String, in context: JavaScriptContext) async throws -> JavaScriptResult
    
    /// Creates a new JavaScript execution context
    /// 
    /// This method creates a new context for JavaScript execution with
    /// the specified parameters.
    /// 
    /// - Parameters:
    ///   - url: The base URL for the context
    ///   - cookies: Optional cookies to include
    ///   - headers: Optional HTTP headers to include
    /// 
    /// - Returns: A new JavaScript execution context
    func createContext(url: URL, cookies: [String: String]?, headers: [String: String]?) -> JavaScriptContext
}

/// Protocol for basic HTTP networking
public protocol NetworkClientProtocol: Sendable {
    /// Perform a request and return data and response
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Protocol for logging
public protocol LoggerProtocol: Sendable {
    /// Log a message at the error level with explicit source location
    func error(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    /// Log a message at the info level with explicit source location
    func info(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    /// Log a message at the debug level with explicit source location
    func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    /// Log a message at the verbose level with explicit source location
    func verbose(_ message: String, category: LogCategory, file: String, function: String, line: Int)
    /// Log a message at the warning level with explicit source location
    func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int)
}

/// Protocol for providing well-known filesystem paths
///
/// Provides platform-aware standard directories used by the application.
public protocol PathProviderProtocol: Sendable {
    /// Returns the user's Downloads directory path
    func downloadsDirectory() -> URL
    /// Returns a temporary directory URL for ephemeral files
    func temporaryDirectory() -> URL
}
