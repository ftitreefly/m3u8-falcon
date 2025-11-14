//
//  NetworkError.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Network Error

/// Network and download related errors
/// 
/// ## Error Codes
/// - 1001: Connection failed
/// - 1002: Invalid URL
/// - 1003: Request timeout
/// - 1004: Server error (5xx)
/// - 1005: Client error (4xx)
/// - 1006: Invalid/unsupported response
/// - 1007: Unknown network error
public struct NetworkError: M3U8FalconError {
    public let domain = "M3U8Falcon.Network"
    public let code: Int
    public let underlyingError: Error?
    public let message: String
    public let url: URL?
    
    public var recoverySuggestion: String? {
        switch code {
        case 1001: return "Check your internet connection and try again."
        case 1002: return "Verify the URL is correct and accessible."
        case 1003: return "The request timed out. Try again with a longer timeout or check your connection."
        case 1004: return "The server is experiencing issues. This will be retried automatically."
        case 1005: return "The request was invalid. Please check the URL and parameters."
        case 1006: return "Received an invalid response from the server."
        case 1007: return "An unknown network error occurred."
        default: return "Check network settings and retry the operation."
        }
    }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = ["message": message]
        if let url = url { info["url"] = url.absoluteString }
        if let underlying = underlyingError { info["underlyingError"] = underlying }
        return info
    }
    
    public var errorDescription: String? {
        return message
    }
    
    public var failureReason: String? {
        return underlyingError?.localizedDescription
    }
    
    // MARK: - Common factory methods
    /// Connection failed for URL
    public static func connectionFailed(_ url: URL, underlying: Error) -> NetworkError {
        NetworkError(
            code: 1001,
            underlyingError: underlying,
            message: "Failed to connect to \(url.host ?? "server")",
            url: url
        )
    }
    
    /// Invalid URL string
    public static func invalidURL(_ urlString: String) -> NetworkError {
        NetworkError(
            code: 1002,
            underlyingError: nil,
            message: "Invalid URL: \(urlString)",
            url: nil
        )
    }
    
    /// Request timeout
    public static func timeout(_ url: URL) -> NetworkError {
        NetworkError(
            code: 1003,
            underlyingError: nil,
            message: "Request timeout for \(url.absoluteString)",
            url: url
        )
    }
    
    /// HTTP server error (5xx) for URL with status code
    public static func serverError(_ url: URL, statusCode: Int) -> NetworkError {
        let code = (statusCode >= 500 && statusCode < 600) ? 1004 : 1006
        return NetworkError(
            code: code,
            underlyingError: nil,
            message: "Server error \(statusCode) for \(url.absoluteString)",
            url: url
        )
    }
    
    /// HTTP client error (4xx) for URL with status code
    public static func clientError(_ url: URL, statusCode: Int) -> NetworkError {
        NetworkError(
            code: 1005,
            underlyingError: nil,
            message: "Client error \(statusCode) for \(url.absoluteString)",
            url: url
        )
    }
    
    /// Invalid or unsupported response
    public static func invalidResponse(_ url: URL) -> NetworkError {
        NetworkError(
            code: 1006,
            underlyingError: nil,
            message: "Invalid response from \(url.absoluteString)",
            url: url
        )
    }
    
    /// Unknown network error
    public static func unknownError() -> NetworkError {
        NetworkError(
            code: 1007,
            underlyingError: nil,
            message: "Unknown network error occurred",
            url: nil
        )
    }
} 
