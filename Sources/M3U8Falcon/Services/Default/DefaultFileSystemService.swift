//
//  DefaultFileSystemService.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Default File System Service

/// Default implementation of basic filesystem utilities
/// 
/// This service wraps `FileManager` with a small, testable API used across
/// the library. It also implements `PathProviderProtocol` for common paths.
public struct DefaultFileSystemService: FileSystemServiceProtocol, PathProviderProtocol {
    // Use FileManager.default directly instead of storing it
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
        return FileManager.default.fileExists(atPath: url.path)
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
    /// The directory name includes a stable or random suffix to avoid collisions.
    /// - Parameter saltString: Optional salt to generate a deterministic suffix
    /// - Returns: URL of the created temporary directory
    /// - Throws: Foundation errors (e.g., `CocoaError`) from `FileManager` on failure
    public func createTemporaryDirectory(_ saltString: String? = nil) throws -> URL {
        let suffixString = saltString.map { String($0.hash, radix: 16).uppercased() } ?? UUID().uuidString
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("M3U8Falcon_".appending(suffixString))
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
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
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
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
        return FileManager.default.temporaryDirectory
    }
}
