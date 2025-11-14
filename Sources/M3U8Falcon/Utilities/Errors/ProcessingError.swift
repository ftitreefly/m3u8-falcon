//
//  ProcessingError.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Processing Error

/// Download and processing related errors
/// 
/// ## Error Codes
/// - 4001: Required external tool not found
/// - 4002: Conversion/processing failed
/// - 4003: Corrupted source file
/// - 4004: Operation cancelled
/// - 4005: Master playlists not supported
/// - 4007: Empty content
/// - 4008: No valid segments
/// - 4009: FFmpeg not found
/// - 4010: Task not found
/// - 4011: No M3U8 links found
/// - 4012: Invalid URL
/// - 4013: Maximum retry attempts exceeded
/// - 4014: Invalid hex string
/// - 4015: Process execution timeout
/// - 4016: Command execution failed
/// - 4017: Invalid command
/// - 4018: Platform-specific error
public struct ProcessingError: M3U8FalconError {
    public let domain = "M3U8Falcon.Processing"
    public let code: Int
    public let underlyingError: Error?
    public let message: String
    public let operation: String?
    
    public var recoverySuggestion: String? {
        switch code {
        case 4001: return "Check if required tools are installed and accessible in PATH."
        case 4002: return "Verify FFmpeg is installed and supports the required codecs."
        case 4003: return "Ensure the source files are not corrupted."
        case 4004: return "Check if the process was interrupted and retry."
        case 4005: return "Master playlists are not supported yet."
        case 4007: return "The downloaded content is empty."
        case 4008: return "No valid segments were found."
        case 4009: return "FFmpeg command was not found."
        case 4010: return "The task was not found."
        case 4011: return "No M3U8 links were found in the content."
        case 4012: return "The URL is invalid."
        case 4013: return "The maximum retry attempts were exceeded."
        case 4014: return "The KEY or IV hex string is invalid."
        case 4015: return "The process execution exceeded the timeout limit. Try increasing the timeout or check system resources."
        case 4016: return "Check the command arguments and ensure the executable exists and is accessible."
        case 4017: return "Verify the command path and ensure it is executable."
        case 4018: return "Check system resources and permissions."
        default: return "Verify external tools are installed and retry the operation."
        }
    }
    
    public var userInfo: [String: Any] {
        var info: [String: Any] = ["message": message]
        if let operation = operation { info["operation"] = operation }
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
    public static func toolNotFound(_ tool: String) -> ProcessingError {
        ProcessingError(
            code: 4001,
            underlyingError: nil,
            message: "Required tool not found: \(tool)",
            operation: "tool check"
        )
    }
    
    public static func conversionFailed(_ reason: String) -> ProcessingError {
        ProcessingError(
            code: 4002,
            underlyingError: nil,
            message: "Video conversion failed",
            operation: reason
        )
    }
    
    public static func corruptedSource(_ path: String) -> ProcessingError {
        ProcessingError(
            code: 4003,
            underlyingError: nil,
            message: "Source file is corrupted: \(path)",
            operation: "validation"
        )
    }
    
    public static func operationCancelled(_ operation: String) -> ProcessingError {
        ProcessingError(
            code: 4004,
            underlyingError: nil,
            message: "Operation was cancelled",
            operation: operation
        )
    }

    public static func masterPlaylistsNotSupported() -> ProcessingError {
        ProcessingError(
            code: 4005,
            underlyingError: nil,
            message: "Master playlists not supported yet",
            operation: "download"
        )
    }

    public static func emptyContent() -> ProcessingError {
        ProcessingError(
            code: 4007,
            underlyingError: nil,
            message: "Downloaded content is empty",
            operation: "download"
        )
    }

    public static func noValidSegments() -> ProcessingError {
        ProcessingError(
            code: 4008,
            underlyingError: nil,
            message: "No valid segments found",
            operation: "segment extraction"
        )
    }

    public static func ffmpegNotFound() -> ProcessingError {
        ProcessingError(
            code: 4009,
            underlyingError: nil,
            message: "FFmpeg command not found",
            operation: "decrypt"
        )
    }

    public static func taskNotFound(_ taskId: String) -> ProcessingError {
        ProcessingError(
            code: 4010,
            underlyingError: nil,
            message: "Task not found: \(taskId)",
            operation: "cancel"
        )
    }
    
    public static func noM3U8LinksFound(_ url: String) -> ProcessingError {
        ProcessingError(
            code: 4011,
            underlyingError: nil,
            message: "No M3U8 links found in: \(url)",
            operation: "extraction"
        )
    }
    
    public static func invalidURL(_ url: String) -> ProcessingError {
        ProcessingError(
            code: 4012,
            underlyingError: nil,
            message: "Invalid URL: \(url)",
            operation: "validation"
        )
    }
    
    public static func maxRetriesExceeded() -> ProcessingError {
        ProcessingError(
            code: 4013,
            underlyingError: nil,
            message: "Maximum retry attempts exceeded",
            operation: "extraction"
        )
    }

    public static func invalidHexString(_ hexString: String) -> ProcessingError {
        ProcessingError(
            code: 4014,
            underlyingError: nil,
            message: "Invalid hex string: \(hexString)",
            operation: "hex string validation"
        )
    }

    public static func timeout(duration: TimeInterval) -> ProcessingError {
        ProcessingError(
            code: 4015,
            underlyingError: nil,
            message: "Process execution timed out after \(duration) seconds",
            operation: "process execution"
        )
    }

    public static func commandFailed(
        command: String,
        exitCode: Int32,
        output: String,
        error: String
    ) -> ProcessingError {
        ProcessingError(
            code: 4016,
            underlyingError: nil,
            message: "Command '\(command)' failed with exit code \(exitCode): \(error.isEmpty ? "No error output" : error)",
            operation: "command execution"
        )
    }

    public static func invalidCommand(command: String, reason: String) -> ProcessingError {
        ProcessingError(
            code: 4017,
            underlyingError: nil,
            message: "Invalid command '\(command)': \(reason)",
            operation: "command validation"
        )
    }

    public static func platformError(underlying: Error, context: String) -> ProcessingError {
        ProcessingError(
            code: 4018,
            underlyingError: underlying,
            message: "Platform error in \(context): \(underlying.localizedDescription)",
            operation: context
        )
    }

    /// Creates a ProcessingError from a command execution result
    public static func fromCommandResult(
        _ result: ProcessResult,
        command: String
    ) -> ProcessingError {
        return commandFailed(
            command: command,
            exitCode: result.exitCode,
            output: result.outputString,
            error: result.errorString
        )
    }

    public init(code: Int, underlyingError: Error?, message: String, operation: String?) {
        self.code = code
        self.underlyingError = underlyingError
        self.message = message
        self.operation = operation
    }
}
