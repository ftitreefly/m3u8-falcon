//
//  DefaultFileSystemService.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// MARK: - Default File System Service

/// Default implementation of basic filesystem utilities
/// 
/// This service wraps `FileManager` with a small, testable API used across
/// the library. It also implements `PathProviderProtocol` for common paths.
/// 
/// This implementation uses `FileManager.default` directly rather than storing
/// a reference, which is safe since `FileManager.default` is thread-safe.
public struct DefaultFileSystemService: FileSystemServiceProtocol, PathProviderProtocol {
    // MARK: - Constants
    
    /// Maximum number of attempts to create a temporary directory
    private static let maxTemporaryDirectoryAttempts = 5
    
    /// Base delay in seconds for exponential backoff retry (10ms)
    private static let retryBaseDelay: TimeInterval = 0.01

    /// Temporary directory name
    private static let temporaryDirectoryPrefix = "M3U8Falcon_"
    
    public init() {}
    
    /// Creates a directory at the given URL
    /// 
    /// - Parameters:
    ///   - url: Destination directory URL
    ///   - withIntermediateDirectories: Whether to create missing intermediates
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: withIntermediateDirectories
        )
    }
    
    /// Checks if a file/directory exists at URL
    /// 
    /// - Parameter url: Target URL
    /// - Returns: `true` if the path exists, otherwise `false`
    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Removes a file or directory
    /// 
    /// - Parameter url: URL to remove
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// Creates a temporary directory for the current process
    /// 
    /// The directory name includes a suffix to avoid collisions:
    /// - If `saltString` is provided: Uses a stable hash of the salt plus timestamp for deterministic naming
    /// - If `saltString` is `nil`: Uses a random UUID for unique naming
    /// 
    /// The function will retry up to `maxTemporaryDirectoryAttempts` times if directory creation
    /// fails due to race conditions or transient I/O errors.
    /// 
    /// - Parameter saltString: Optional salt string to generate a deterministic directory name.
    ///   When provided, the same salt will produce the same hash (but different timestamps ensure uniqueness).
    /// - Returns: URL of the created temporary directory
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func createTemporaryDirectory(_ saltString: String? = nil) throws -> URL {
        let initialSuffix: String
        if let salt = saltString {
            let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
            let hashString = Self.stableHashString(for: salt)
            initialSuffix = "\(hashString)_\(timestamp)"
        } else {
            initialSuffix = UUID().uuidString
        }
        
        var attempt = 0
        let maxAttempts = Self.maxTemporaryDirectoryAttempts
        
        while attempt < maxAttempts {
            let suffix: String
            if attempt == 0 {
                suffix = initialSuffix
            } else {
                // Add attempt number and additional UUID for uniqueness on retry
                suffix = "\(initialSuffix)_\(attempt)_\(UUID().uuidString.prefix(8))"
            }
            
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(Self.temporaryDirectoryPrefix + suffix)
            
            // Check if directory already exists
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &isDirectory)
            
            if exists {
                if isDirectory.boolValue {
                    // Directory exists - verify it's writable before returning
                    if Self.isDirectoryWritable(at: tempDir) {
                        return tempDir
                    }
                    // Directory exists but not writable - try again with new name
                    attempt += 1
                    continue
                } else {
                    // Path exists but is not a directory - try again with new name
                    attempt += 1
                    continue
                }
            }
            
            // Try to create the directory
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                return tempDir
            } catch let error as CocoaError {
                // Handle specific error cases
                switch error.code {
                case .fileWriteFileExists:
                    // Directory was created by another process between check and create
                    // Verify it's actually a directory and writable, then return it
                    var checkIsDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: tempDir.path, isDirectory: &checkIsDirectory),
                       checkIsDirectory.boolValue,
                       Self.isDirectoryWritable(at: tempDir) {
                        return tempDir
                    }
                    // Otherwise, try again with new name
                    attempt += 1
                    continue
                    
                case .fileWriteNoPermission:
                    // Permission error - don't retry
                    throw error
                    
                default:
                    // For I/O errors and other transient errors, retry with exponential backoff
                    if attempt < maxAttempts - 1 {
                        attempt += 1
                        // Minimal blocking delay for retry (exponential backoff)
                        // Note: Thread.sleep is acceptable here since this is a synchronous function
                        // and the delay is minimal (10-50ms)
                        Thread.sleep(forTimeInterval: Double(attempt) * Self.retryBaseDelay)
                        continue
                    } else {
                        throw error
                    }
                }
            } catch {
                // For non-CocoaError exceptions, retry if we have attempts left
                if attempt < maxAttempts - 1 {
                    attempt += 1
                    // Minimal blocking delay for retry (exponential backoff)
                    Thread.sleep(forTimeInterval: Double(attempt) * Self.retryBaseDelay)
                    continue
                } else {
                    throw error
                }
            }
        }
        
        // Fallback: create directory with UUID suffix
        // This should rarely be reached, but provides a safety net
        let fallbackDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.temporaryDirectoryPrefix)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
        return fallbackDir
    }
    
    /// Generates a stable hash string for deterministic naming
    /// 
    /// Uses CryptoKit's SHA256 when available for cross-platform stability and
    /// cryptographic strength. Otherwise falls back to a DJB2-like hash function
    /// which is more stable than Swift's `String.hash` (which can vary between
    /// Swift versions and process runs).
    /// 
    /// - Parameter input: Input string to hash
    /// - Returns: Hexadecimal hash string (uppercase)
    private static func stableHashString(for input: String) -> String {
        #if canImport(CryptoKit)
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
        #else
        var hash = 5381
        for char in input.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return String(format: "%016X", UInt64(truncatingIfNeeded: hash))
        #endif
    }
    
    /// Checks if a directory is writable
    /// 
    /// - Parameter url: Directory URL to check
    /// - Returns: `true` if the directory exists and is writable, `false` otherwise
    private static func isDirectoryWritable(at url: URL) -> Bool {
        // Check if we can write to the directory by attempting to create a test file
        let testFile = url.appendingPathComponent(".write_test_\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            // Clean up test file - ignore errors during cleanup as they don't affect
            // the writability check result
            _ = try? FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            _ = try? FileManager.default.removeItem(at: testFile)
            return false
        }
    }

    /// Reads file content as UTF-8 string
    /// 
    /// - Parameter url: File URL
    /// - Returns: File content decoded as UTF-8
    /// - Throws: `FileSystemError.failedToReadFromFile` when decoding fails or file is unreadable
    public func content(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw FileSystemError.failedToReadFromFile(url.path)
        }
        return content
    }
    
    /// Lists directory contents (non-recursive)
    /// 
    /// - Parameter url: Directory URL
    /// - Returns: Array of item URLs
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    /// Copies a file from source to destination
    /// 
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    // MARK: - PathProviderProtocol
    /// Returns the user's Downloads directory
    /// 
    /// On Linux, this method checks XDG environment variables and configuration files
    /// before falling back to the standard Downloads directory. On macOS and other
    /// platforms, it uses the system's standard Downloads directory.
    public func downloadsDirectory() -> URL {
        #if os(Linux)
        // Try XDG_DOWNLOAD_DIR environment variable first
        if let envPath = ProcessInfo.processInfo.environment["XDG_DOWNLOAD_DIR"], !envPath.isEmpty {
            if let xdgURL = normalizeXDGPath(envPath) {
                return xdgURL
            }
        }
        
        // Try reading from user-dirs.dirs config file
        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("user-dirs.dirs", isDirectory: false)
        
        if let contents = try? String(contentsOf: configFile, encoding: .utf8) {
            for line in contents.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasPrefix("XDG_DOWNLOAD_DIR=") else { continue }
                
                let valueStart = trimmed.index(trimmed.startIndex, offsetBy: "XDG_DOWNLOAD_DIR=".count)
                var value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
                value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                
                if let xdgURL = normalizeXDGPath(String(value)) {
                    return xdgURL
                }
            }
        }
        #endif
        
        // Fallback to standard system method
        let urls = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        return (urls.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
    }
    
    #if os(Linux)
    /// Normalizes and expands XDG path strings
    /// 
    /// Expands environment variables in the format $VAR or ${VAR} and tilde (~)
    /// to create a valid absolute path URL.
    private func normalizeXDGPath(_ rawPath: String) -> URL? {
        guard !rawPath.isEmpty else { return nil }
        var path = rawPath
        
        // Expand all environment variables in the format $VAR or ${VAR}
        let environment = ProcessInfo.processInfo.environment
        
        // Pattern for ${VAR} format
        var pattern = #/\$\{([A-Z_][A-Z0-9_]*)\}/#
        while let match = path.firstMatch(of: pattern) {
            let varName = String(match.1)
            if let value = environment[varName] {
                path = path.replacingOccurrences(of: "${\(varName)}", with: value)
            } else {
                // If variable not found, remove it
                path = path.replacingOccurrences(of: "${\(varName)}", with: "")
            }
        }
        
        // Pattern for $VAR format
        pattern = #/\$([A-Z_][A-Z0-9_]*)/#
        while let match = path.firstMatch(of: pattern) {
            let varName = String(match.1)
            if let value = environment[varName] {
                path = path.replacingOccurrences(of: "$\(varName)", with: value)
            } else {
                // If variable not found, remove it
                path = path.replacingOccurrences(of: "$\(varName)", with: "")
            }
        }
        
        // Expand tilde after environment variables (in case ~ was in an env var)
        // Note: Using NSString API for tilde expansion as it's the standard way on Unix systems
        // and is available on both macOS and Linux
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }
        
        // Final validation - path must be absolute after expansion
        guard path.hasPrefix("/") else {
            return nil
        }
        
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    #endif
    
    /// Returns the process temporary directory
    public func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
    }
}
