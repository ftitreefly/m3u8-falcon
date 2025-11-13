//
//  ErrorHandling.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Core Error Protocol

/// Core error protocol that all M3U8Falcon errors conform to
/// 
/// This protocol defines the standard interface for all errors in the M3U8Falcon
/// library, providing consistent error handling, localization, and context information.
/// 
/// ## Features
/// - Domain-based error categorization
/// - Unique error codes for programmatic handling
/// - Underlying error preservation
/// - Localized error descriptions and recovery suggestions
/// - Rich context information for debugging
/// 
/// ## Usage Example
/// ```swift
/// struct MyCustomError: M3U8FalconError {
///     let domain = "M3U8Falcon.Custom"
///     let code: Int
///     let underlyingError: Error?
///     let message: String
///     
///     var recoverySuggestion: String? {
///         return "Try again with different parameters"
///     }
///     
///     var userInfo: [String: Any] {
///         return ["message": message]
///     }
/// }
/// ```
public protocol M3U8FalconError: Error, LocalizedError, Sendable {
    /// The error domain for categorization
    /// 
    /// Used to group related errors and provide namespace separation.
    /// Example: "M3U8Falcon.Network", "M3U8Falcon.Parsing"
    var domain: String { get }
    
    /// A unique error code within the domain
    /// 
    /// Numeric code that uniquely identifies the specific error within its domain.
    /// Used for programmatic error handling and logging.
    var code: Int { get }
    
    /// The underlying cause of the error
    /// 
    /// The original error that caused this error, if any. Useful for debugging
    /// and preserving the complete error chain.
    var underlyingError: Error? { get }
    
    /// Recovery suggestions for the user
    /// 
    /// Human-readable suggestions for how to resolve the error.
    /// Should provide actionable advice when possible.
    var recoverySuggestion: String? { get }
    
    /// Additional context information
    /// 
    /// Dictionary containing additional information about the error context,
    /// useful for debugging and logging purposes.
    var userInfo: [String: Any] { get }
}

// MARK: - Specific Error Types

/// Configuration and validation errors
/// 
/// This struct represents errors that occur during configuration validation
/// and parameter checking. It provides specific error codes and recovery
/// suggestions for common configuration issues.
/// 
/// ## Error Codes
/// - **5001**: Missing required parameter
/// - **5002**: Invalid parameter value
/// - **5003**: Unsupported configuration
/// 
/// ## Usage Example
/// ```swift
/// // Check for missing parameter
/// guard let url = configuration.url else {
///     throw ConfigurationError.missingParameter("url")
/// }
/// 
/// // Validate parameter value
/// guard url.scheme == "https" else {
///     throw ConfigurationError.invalidParameterValue("url", value: url.absoluteString)
/// }
/// ```
public struct ConfigurationError: M3U8FalconError {
    /// Error domain for configuration errors
    public let domain = "M3U8Falcon.Configuration"
    
    /// Unique error code
    public let code: Int
    
    /// Underlying error that caused this configuration error
    public let underlyingError: Error?
    
    /// Human-readable error message
    public let message: String
    
    /// Name of the parameter that caused the error
    public let parameter: String?
    
    /// Recovery suggestions based on error code
    /// 
    /// Provides specific guidance for resolving the configuration error
    /// based on the error code.
    public var recoverySuggestion: String? {
        switch code {
        case 5001: return "Provide a valid value for the required parameter."
        case 5002: return "Check the parameter value against the expected format."
        case 5003: return "Ensure all required configuration is provided."
        case 5004: return "Check the service type and underlying error for more details."
        default: return "Verify configuration parameters and retry."
        }
    }
    
    /// Additional context information for debugging
    /// 
    /// Includes the error message, parameter name, and underlying error
    /// for comprehensive debugging information.
    public var userInfo: [String: Any] {
        var info: [String: Any] = ["message": message]
        if let parameter = parameter { info["parameter"] = parameter }
        if let underlying = underlyingError { info["underlyingError"] = underlying }
        return info
    }
    
    /// Localized error description
    public var errorDescription: String? {
        return message
    }
    
    /// Localized failure reason
    public var failureReason: String? {
        return parameter.map { "Parameter: \($0)" }
    }
    
    /// Creates an error for missing required parameters
    /// 
    /// - Parameter parameter: The name of the missing parameter
    /// 
    /// - Returns: A configuration error with code 5001
    public static func missingParameter(_ parameter: String) -> ConfigurationError {
        ConfigurationError(
            code: 5001,
            underlyingError: nil,
            message: "Missing required parameter",
            parameter: parameter
        )
    }
    
    /// Creates an error for invalid parameter values
    /// 
    /// - Parameters:
    ///   - parameter: The name of the parameter
    ///   - value: The invalid value that was provided
    /// 
    /// - Returns: A configuration error with code 5002
    public static func invalidParameterValue(_ parameter: String, value: String) -> ConfigurationError {
        ConfigurationError(
            code: 5002,
            underlyingError: nil,
            message: "Invalid parameter value: \(value)",
            parameter: parameter
        )
    }
    
    /// Creates an error for unsupported configurations
    /// 
    /// - Parameter configuration: The unsupported configuration name
    /// 
    /// - Returns: A configuration error with code 5003
    public static func unsupportedConfiguration(_ configuration: String) -> ConfigurationError {
        ConfigurationError(
            code: 5003,
            underlyingError: nil,
            message: "Unsupported configuration",
            parameter: configuration
        )
    }
    
    /// Creates an error for service resolution failures
    /// 
    /// - Parameters:
    ///   - serviceType: The type of service that failed to resolve
    ///   - underlyingError: The underlying error that caused the failure
    /// 
    /// - Returns: A configuration error with code 5004
    public static func serviceResolutionFailed(serviceType: String, underlyingError: Error) -> ConfigurationError {
        ConfigurationError(
            code: 5004,
            underlyingError: underlyingError,
            message: "Failed to resolve service: \(serviceType)",
            parameter: serviceType
        )
    }
}

// MARK: - Error Result Types

/// Result type for operations that can fail with specific error types
/// 
/// These type aliases provide convenient result types for operations that
/// can fail with specific error categories, making error handling more
/// explicit and type-safe.
public typealias NetworkResult<Success> = Result<Success, NetworkError>
public typealias ParsingResult<Success> = Result<Success, ParsingError>
public typealias FileSystemResult<Success> = Result<Success, FileSystemError>
public typealias ProcessingResult<Success> = Result<Success, ProcessingError>
public typealias ConfigurationResult<Success> = Result<Success, ConfigurationError>

// MARK: - Error Utilities

/// Utility functions for error handling and conversion
/// 
/// This enum provides static methods for common error handling operations,
/// including error conversion and contextual error creation.
public enum ErrorHandling {
    /// Converts any error to appropriate M3U8FalconError
    /// 
    /// This method attempts to convert system errors and other error types
    /// into appropriate M3U8FalconError instances for consistent error handling.
    /// 
    /// - Parameters:
    ///   - error: The error to convert
    ///   - context: Optional context information about the operation
    /// 
    /// - Returns: A M3U8FalconError instance representing the original error
    /// 
    /// ## Usage Example
    /// ```swift
    /// do {
    ///     try someOperation()
    /// } catch {
    ///     let tfError = ErrorHandling.convert(error, context: "download operation")
    ///     print("Error: \(tfError.localizedDescription)")
    ///     print("Recovery: \(tfError.recoverySuggestion ?? "Unknown")")
    /// }
    /// ```
    public static func convert(_ error: Error, context: String? = nil) -> any M3U8FalconError {
        if let tfError = error as? any M3U8FalconError {
            return tfError
        }
        
        // Convert common system errors
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSURLErrorDomain:
                return NetworkError(
                    code: 1001,
                    underlyingError: error,
                    message: "Network error occurred",
                    url: nil
                )
            case NSCocoaErrorDomain:
                return FileSystemError(
                    code: 3001,
                    underlyingError: error,
                    message: "File system error occurred",
                    path: nil
                )
            default:
                return ProcessingError(
                    code: 4999,
                    underlyingError: error,
                    message: "Unknown error occurred",
                    operation: context
                )
            }
        }
        
        return ProcessingError(
            code: 4999,
            underlyingError: error,
            message: error.localizedDescription,
            operation: context
        )
    }
    
    /// Creates a standardized error message with context
    /// 
    /// This method enhances an existing error with additional context information,
    /// making it more useful for debugging and logging.
    /// 
    /// - Parameters:
    ///   - error: The original error to enhance
    ///   - operation: The operation that was being performed
    ///   - additionalInfo: Additional context information to include
    /// 
    /// - Returns: The enhanced error with additional context
    /// 
    /// ## Usage Example
    /// ```swift
    /// let error = NetworkError.serverError(url, statusCode: 404)
    /// let contextualError = ErrorHandling.createContextualError(
    ///     error,
    ///     operation: "download playlist",
    ///     additionalInfo: ["attempt": 3, "timeout": 30]
    /// )
    /// ```
    public static func createContextualError<T: M3U8FalconError>(_ error: T,
                                                             operation: String,
                                                             additionalInfo: [String: Any] = [:]) -> T {
        var newUserInfo = error.userInfo
        newUserInfo["operation"] = operation
        for (key, value) in additionalInfo {
            newUserInfo[key] = value
        }
        
        // Return the error with updated context
        return error
    }
} 
