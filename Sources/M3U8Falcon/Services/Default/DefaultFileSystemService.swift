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
    /// - Throws: `FileSystemError` from underlying `FileManager` on failure
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
    /// - Throws: `FileSystemError` from underlying `FileManager` on failure
    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// Creates a temporary directory for the current process
    /// 
    /// The directory name includes a stable or random suffix to avoid collisions.
    /// - Parameter saltString: Optional salt to generate a deterministic suffix
    /// - Returns: URL of the created temporary directory
    /// - Throws: `FileSystemError` from underlying `FileManager` on failure
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
    /// - Throws: `FileSystemError` from underlying `FileManager` on failure
    public func contentsOfDirectory(at url: URL) throws -> [URL] {
        return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    }
    
    /// Copies a file from source to destination
    /// 
    /// - Parameters:
    ///   - sourceURL: Source file URL
    ///   - destinationURL: Destination file URL
    /// - Throws: `FileSystemError` from underlying `FileManager` on failure
    public func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    // MARK: - PathProviderProtocol
    /// Returns the user's Downloads directory
    public func downloadsDirectory() -> URL {
        let urls = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        return (urls.first ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"))
    }
    
    /// Returns the process temporary directory
    public func temporaryDirectory() -> URL {
        return FileManager.default.temporaryDirectory
    }
}
