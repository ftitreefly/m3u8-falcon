//
//  Logger.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/16.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Foundation)
// Windows or other platforms - Foundation should provide what we need
#endif
import Foundation

// MARK: - Log Level

/// Represents different levels of logging detail
/// 
/// This enum defines the various logging levels available in the system,
/// allowing for fine-grained control over what information is displayed.
public enum LogLevel: Int, CaseIterable, Comparable, Sendable {
    /// No logging output
    case none = 0
    
    /// Only critical errors and warnings
    case error = 1
    
    /// Important information and errors
    case info = 2
    
    /// Detailed debugging information
    case debug = 3
    
    /// Very detailed debugging information
    case verbose = 4
    
    /// All possible information including trace data
    case trace = 5
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category

/// Categories for organizing log messages
/// 
/// This enum helps categorize log messages for better organization
/// and filtering capabilities.
public enum LogCategory: String, CaseIterable, Sendable {
    case general = "General"
    case network = "Network"
    case fileSystem = "FileSystem"
    case parsing = "Parsing"
    case processing = "Processing"
    case taskManager = "TaskManager"
    case download = "Download"
    case cli = "CLI"
    case extraction = "Extraction"
    
    var emoji: String {
        switch self {
        case .general: return "📋"
        case .network: return "🌐"
        case .fileSystem: return "📁"
        case .parsing: return "📝"
        case .processing: return "⚙️"
        case .taskManager: return "🎯"
        case .download: return "⬇️"
        case .cli: return "💻"
        case .extraction: return "🔗"
        }
    }
}

// MARK: - Logger Configuration

/// Configuration for the logging system
/// 
/// This struct contains all the configuration options for the logging system,
/// allowing for fine-grained control over logging behavior.
public struct LoggerConfiguration: Sendable {
    /// The minimum log level to display
    public let minimumLevel: LogLevel
    
    /// Whether to include timestamps in log messages
    public let includeTimestamps: Bool
    
    /// Whether to include category information in log messages
    public let includeCategories: Bool
    
    /// Whether to include emoji in log messages
    public let includeEmoji: Bool
    
    /// Whether to enable colored output (if supported)
    public let enableColors: Bool
    
    /// Initializes a new logger configuration
    /// 
    /// - Parameters:
    ///   - minimumLevel: The minimum log level to display (defaults to .info)
    ///   - includeTimestamps: Whether to include timestamps (defaults to true)
    ///   - includeCategories: Whether to include categories (defaults to true)
    ///   - includeEmoji: Whether to include emoji (defaults to true)
    ///   - enableColors: Whether to enable colored output (defaults to true)
    public init(
        minimumLevel: LogLevel = .info,
        includeTimestamps: Bool = true,
        includeCategories: Bool = true,
        includeEmoji: Bool = true,
        enableColors: Bool = true
    ) {
        self.minimumLevel = minimumLevel
        self.includeTimestamps = includeTimestamps
        self.includeCategories = includeCategories
        self.includeEmoji = includeEmoji
        self.enableColors = enableColors
    }
    
    /// Creates a configuration suitable for production use
    public static func production() -> LoggerConfiguration {
        return LoggerConfiguration(
            minimumLevel: .error,
            includeTimestamps: false,
            includeCategories: true,
            includeEmoji: false,
            enableColors: false
        )
    }
    
    /// Creates a configuration suitable for development use
    public static func development() -> LoggerConfiguration {
        return LoggerConfiguration(
            minimumLevel: .debug,
            includeTimestamps: true,
            includeCategories: true,
            includeEmoji: true,
            enableColors: true
        )
    }
    
    /// Creates a configuration suitable for verbose debugging
    public static func verbose() -> LoggerConfiguration {
        return LoggerConfiguration(
            minimumLevel: .trace,
            includeTimestamps: false,
            includeCategories: true,
            includeEmoji: true,
            enableColors: true
        )
    }
}

// MARK: - Logger

/// A comprehensive logging system for M3U8Falcon
/// 
/// This class provides a unified logging interface that can be configured
/// to display different levels of detail based on the current needs.
/// It supports multiple log levels, categories, timestamps, and colored output.
/// 
/// ## Features
/// - Multiple log levels (none, error, info, debug, verbose, trace)
/// - Categorized logging for better organization
/// - Configurable output formatting
/// - Thread-safe logging operations
/// - Support for custom output streams
/// - Colored output support
/// 
/// ## Usage Example
/// ```swift
/// // Configure logger
/// Logger.configure(.development())
/// 
/// // Log messages
/// Logger.info("Application started", category: .general)
/// Logger.debug("Downloading file", category: .download)
/// Logger.error("Network error", category: .network)
/// 
/// // Conditional logging
/// Logger.verbose("Detailed debug info", category: .parsing)
/// ```
public struct Logger: LoggerProtocol {
    public init() {}
    /// The current configuration for the logger (accessed via configQueue)
    // Configuration is managed by LoggerState below
    
    /// Thread-safe queue for emitting logs
    private static let logQueue = DispatchQueue(label: "com.m3u8falcon.logger", qos: .utility)

    /// Internal state container for configuration (serialized access)
    private final class LoggerState: @unchecked Sendable {
        private var configuration: LoggerConfiguration = .development()
        private let queue = DispatchQueue(label: "com.m3u8falcon.logger.config", qos: .utility)
        func getConfig() -> LoggerConfiguration { queue.sync { configuration } }
        func setConfig(_ cfg: LoggerConfiguration) { queue.sync { configuration = cfg } }
    }
    private static let state = LoggerState()
    
    /// TTY detection for color/emoji output
    private static let stdoutIsTTY: Bool = (isatty(STDOUT_FILENO) != 0)
    
    /// Cached DateFormatter (used only on logQueue)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// Configure the logger with a specific configuration
    /// 
    /// This method should be called once at application startup to configure
    /// the logging behavior for the entire application.
    /// 
    /// - Parameter config: The configuration to use for logging
    public static func configure(_ config: LoggerConfiguration) {
        state.setConfig(config)
    }

    nonisolated public func error(_ message: String, category: LogCategory, file: String, function: String, line: Int) {
        Logger.log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    nonisolated public func info(_ message: String, category: LogCategory, file: String, function: String, line: Int) {
        Logger.log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    nonisolated public func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int) {
        Logger.log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    nonisolated public func verbose(_ message: String, category: LogCategory, file: String, function: String, line: Int) {
        Logger.log(.verbose, message: message, category: category, file: file, function: function, line: line)
    }
    nonisolated public func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int) {
        Logger.log(.info, message: "⚠️  \(message)", category: category, file: file, function: function, line: line)
    }
    
    /// Log a message at the error level
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line number (automatically captured)
    // Convenience overloads that capture call-site location for direct static usage
    public static func error(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a message at the info level
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line number (automatically captured)
    public static func info(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a message at the debug level
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line number (automatically captured)
    public static func debug(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a message at the verbose level
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line number (automatically captured)
    public static func verbose(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.verbose, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a message at the trace level
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    ///   - file: The source file (automatically captured)
    ///   - function: The source function (automatically captured)
    ///   - line: The source line number (automatically captured)
    public static func trace(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.trace, message: message, category: category, file: file, function: function, line: line)
    }
    
    /// Log a success message (info level with success formatting)
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    public static func success(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message: "✅ \(message)", category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message (info level with warning formatting)
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    public static func warning(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message: "⚠️  \(message)", category: category, file: file, function: function, line: line)
    }
    
    /// Log a progress message (info level with progress formatting)
    /// 
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The category of the log message (defaults to .general)
    public static func progress(
        _ message: String,
        category: LogCategory = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message: "📊 \(message)", category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    /// Internal logging method that handles the actual log output
    /// 
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - category: The category of the log message
    ///   - file: The source file
    ///   - function: The source function
    ///   - line: The source line number
    private static func log(
        _ level: LogLevel,
        message: String,
        category: LogCategory = .general,
        file: String,
        function: String,
        line: Int
    ) {
        // Snapshot configuration safely
        let cfg = state.getConfig()
        guard level <= cfg.minimumLevel else { return }
        
        logQueue.async {
            let formattedMessage = formatMessage(
                level: level,
                message: message,
                category: category,
                fileAndLine: "\(file):\(line)",
                function: function,
                cfg: cfg
            )
            print(formattedMessage)
        }
    }
    
    /// Format a log message according to the current configuration
    /// 
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - category: The category of the log message
    ///   - fileAndLine: The source file and line number
    ///   - function: The source function
    /// - Returns: The formatted log message
    private static func formatMessage(
        level: LogLevel,
        message: String,
        category: LogCategory,
        fileAndLine: String,
        function: String,
        cfg: LoggerConfiguration
    ) -> String {
        var components: [String] = []
        
        // Add timestamp if enabled (formatter used only on logQueue)
        if cfg.includeTimestamps {
            components.append(dateFormatter.string(from: Date()))
        }
        
        // Add level indicator
        let levelIndicator = levelIndicator(for: level, cfg: cfg)
        components.append(levelIndicator)
        
        // Add category if enabled
        if cfg.includeCategories {
            let categoryText = (cfg.includeEmoji && stdoutIsTTY) ? 
                "\(category.emoji)\(category.rawValue)" : 
                category.rawValue
            components.append("[\(categoryText)]")
        }
        
        // Add message
        components.append(message)
        
        // Add source location for debug and trace levels
        if level >= .debug && cfg.minimumLevel >= .debug {
            components.append("(\(fileAndLine))")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Get the level indicator for a log level
    /// 
    /// - Parameter level: The log level
    /// - Returns: The level indicator string
    private static func levelIndicator(for level: LogLevel, cfg: LoggerConfiguration) -> String {
        let baseIndicator: String
        switch level {
        case .none: baseIndicator = "NONE"
        case .error: baseIndicator = "ERROR"
        case .info: baseIndicator = "INFO"
        case .debug: baseIndicator = "DEBUG"
        case .verbose: baseIndicator = "VERBOSE"
        case .trace: baseIndicator = "TRACE"
        }
        
        if cfg.enableColors && stdoutIsTTY {
            return colorize(baseIndicator, for: level)
        } else {
            return "[\(baseIndicator)]"
        }
    }
    
    /// Add color to a string based on log level
    /// 
    /// - Parameters:
    ///   - string: The string to colorize
    ///   - level: The log level
    /// - Returns: The colorized string
    private static func colorize(_ string: String, for level: LogLevel) -> String {
        let colorCode: String
        switch level {
        case .none: colorCode = "0"
        case .error: colorCode = "31" // Red
        case .info: colorCode = "32"  // Green
        case .debug: colorCode = "34" // Blue
        case .verbose: colorCode = "35" // Magenta
        case .trace: colorCode = "36" // Cyan
        }
        
        return "\u{001B}[\(colorCode)m[\(string)]\u{001B}[0m"
    }
}

// MARK: - Logger Extensions

public extension Logger {
    /// Convenience method for logging with a specific configuration
    /// 
    /// This method allows logging with a temporary configuration override
    /// without changing the global configuration.
    /// 
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - category: The category of the log message
    ///   - config: The configuration to use for this log
    static func log(
        _ level: LogLevel,
        _ message: String,
        category: LogCategory = .general,
        with config: LoggerConfiguration
    ) {
        // Emit with a temporary configuration without mutating global state
        let formatted = Logger.formatMessage(
            level: level,
            message: message,
            category: category,
            fileAndLine: "",
            function: "",
            cfg: config
        )
        Logger.logQueue.async { print(formatted) }
    }
} 

// Thin adapter to use static Logger via LoggerProtocol
public struct LoggerAdapter: LoggerProtocol {
    public init() {}
    public func error(_ message: String, category: LogCategory, file: String, function: String, line: Int) { 
        Logger.error(message, category: category, file: file, function: function, line: line) 
    }
    public func info(_ message: String, category: LogCategory, file: String, function: String, line: Int) { 
        Logger.info(message, category: category, file: file, function: function, line: line) 
    }
    public func debug(_ message: String, category: LogCategory, file: String, function: String, line: Int) { 
        Logger.debug(message, category: category, file: file, function: function, line: line) 
    }
    public func verbose(_ message: String, category: LogCategory, file: String, function: String, line: Int) { 
        Logger.verbose(message, category: category, file: file, function: function, line: line) 
    }
    public func warning(_ message: String, category: LogCategory, file: String, function: String, line: Int) { 
        Logger.warning(message, category: category, file: file, function: function, line: line) 
    }
}


public extension LoggerProtocol {
    func error(_ message: String, category: LogCategory, file: String = #fileID, function: String = #function, line: Int = #line) {
        self.error(message, category: category, file: file, function: function, line: line)
    }
    func info(_ message: String, category: LogCategory, file: String = #fileID, function: String = #function, line: Int = #line) {
        self.info(message, category: category, file: file, function: function, line: line)
    }
    func debug(_ message: String, category: LogCategory, file: String = #fileID, function: String = #function, line: Int = #line) {
        self.debug(message, category: category, file: file, function: function, line: line)
    }
    func verbose(_ message: String, category: LogCategory, file: String = #fileID, function: String = #function, line: Int = #line) {
        self.verbose(message, category: category, file: file, function: function, line: line)
    }
    func warning(_ message: String, category: LogCategory, file: String = #fileID, function: String = #function, line: Int = #line) {
        self.warning(message, category: category, file: file, function: function, line: line)
    }
}

// Convenience overloads so call sites can omit file/function/line and still capture them here.
public extension LoggerProtocol {
    func error(_ message: String, category: LogCategory) {
        self.error(message, category: category, file: #fileID, function: #function, line: #line)
    }
    func info(_ message: String, category: LogCategory) {
        self.info(message, category: category, file: #fileID, function: #function, line: #line)
    }
    func debug(_ message: String, category: LogCategory) {
        self.debug(message, category: category, file: #fileID, function: #function, line: #line)
    }
    func verbose(_ message: String, category: LogCategory) {
        self.verbose(message, category: category, file: #fileID, function: #function, line: #line)
    }
    func warning(_ message: String, category: LogCategory) {
        self.warning(message, category: category, file: #fileID, function: #function, line: #line)
    }
}