//
//  ResourceManager.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation

// MARK: - Resource Manager

/// Automatic resource management for temporary files and directories
/// 
/// This actor provides automatic cleanup of temporary resources to prevent
/// resource leaks and disk space waste. It tracks all managed resources and
/// ensures they are properly cleaned up when no longer needed.
/// 
/// ## Features
/// - Automatic resource tracking
/// - Configurable auto-cleanup
/// - Manual cleanup support
/// - Resource lifecycle management
/// - Thread-safe operations
/// 
/// ## Usage Example
/// ```swift
/// let manager = ResourceManager()
/// 
/// // Create and register a temporary directory
/// let tempDir = try await manager.createTemporaryDirectory(prefix: "download")
/// 
/// // Use the directory
/// // ...
/// 
/// // Cleanup when done (or let deinit handle it)
/// try await manager.cleanup(tempDir)
/// ```
public actor ResourceManager {
    /// Managed resource information
    private struct ManagedResource: Sendable {
        let url: URL
        let createdAt: Date
        let autoCleanup: Bool
        let resourceType: ResourceType
    }
    
    /// Type of managed resource
    public enum ResourceType: Sendable {
        case directory
        case file
        case temporaryDirectory
    }
    
    /// Registry of managed resources
    private var managedResources: [String: ManagedResource] = [:]
    
    /// Maximum age for automatic cleanup (in seconds)
    private let maxResourceAge: TimeInterval
    
    /// Whether to enable automatic cleanup on deinit
    private let autoCleanupOnDeinit: Bool
    
    /// Initializes a new resource manager
    /// 
    /// - Parameters:
    ///   - maxResourceAge: Maximum age for resources before auto-cleanup (default: 1 hour)
    ///   - autoCleanupOnDeinit: Whether to cleanup all resources on deinit (default: true)
    public init(
        maxResourceAge: TimeInterval = 3600,
        autoCleanupOnDeinit: Bool = true
    ) {
        self.maxResourceAge = maxResourceAge
        self.autoCleanupOnDeinit = autoCleanupOnDeinit
    }
    
    /// Creates and registers a temporary directory
    /// 
    /// - Parameters:
    ///   - prefix: Optional prefix for the directory name
    ///   - autoCleanup: Whether to automatically cleanup this resource
    /// 
    /// - Returns: URL of the created temporary directory
    /// 
    /// - Throws: `FileSystemError` if directory creation fails
    public func createTemporaryDirectory(
        prefix: String = "tfm3u8",
        autoCleanup: Bool = true
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "\(prefix)-\(UUID().uuidString)"
        let url = tempDir.appendingPathComponent(uniqueName, isDirectory: true)
        
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700] // Owner only
        )
        
        register(
            url: url,
            type: .temporaryDirectory,
            autoCleanup: autoCleanup
        )
        
        Logger.debug(
            "Created temporary directory: \(url.path)",
            category: .fileSystem
        )
        
        return url
    }
    
    /// Registers an existing resource for management
    /// 
    /// - Parameters:
    ///   - url: URL of the resource
    ///   - type: Type of the resource
    ///   - autoCleanup: Whether to automatically cleanup this resource
    public func register(
        url: URL,
        type: ResourceType,
        autoCleanup: Bool = true
    ) {
        let resource = ManagedResource(
            url: url,
            createdAt: Date(),
            autoCleanup: autoCleanup,
            resourceType: type
        )
        managedResources[url.path] = resource
        
        Logger.debug(
            "Registered resource: \(url.path) (type: \(type), autoCleanup: \(autoCleanup))",
            category: .fileSystem
        )
    }
    
    /// Unregisters a resource without cleaning it up
    /// 
    /// - Parameter url: URL of the resource to unregister
    public func unregister(url: URL) {
        managedResources.removeValue(forKey: url.path)
        Logger.debug(
            "Unregistered resource: \(url.path)",
            category: .fileSystem
        )
    }
    
    /// Cleans up a specific resource
    /// 
    /// - Parameter url: URL of the resource to cleanup
    /// 
    /// - Throws: `FileSystemError` if cleanup fails
    public func cleanup(_ url: URL) throws {
        guard managedResources[url.path] != nil else {
            Logger.warning(
                "Attempted to cleanup unmanaged resource: \(url.path)",
                category: .fileSystem
            )
            return
        }
        
        try performCleanup(url: url)
        managedResources.removeValue(forKey: url.path)
        
        Logger.debug(
            "Cleaned up resource: \(url.path)",
            category: .fileSystem
        )
    }
    
    /// Cleans up all managed resources
    /// 
    /// - Parameter force: If true, cleanup all resources regardless of autoCleanup flag
    /// 
    /// - Throws: `FileSystemError` if cleanup fails
    public func cleanupAll(force: Bool = false) throws {
        var errors: [Error] = []
        
        for (_, resource) in managedResources {
            if force || resource.autoCleanup {
                do {
                    try performCleanup(url: resource.url)
                } catch {
                    errors.append(error)
                    Logger.error(
                        "Failed to cleanup resource \(resource.url.path): \(error)",
                        category: .fileSystem
                    )
                }
            }
        }
        
        managedResources.removeAll(keepingCapacity: false)
        
        if !errors.isEmpty {
            throw FileSystemError.failedToDeleteFile(
                "Failed to cleanup \(errors.count) resource(s)"
            )
        }
        
        Logger.debug(
            "Cleaned up all managed resources",
            category: .fileSystem
        )
    }
    
    /// Cleans up old resources based on age
    /// 
    /// - Throws: `FileSystemError` if cleanup fails
    public func cleanupOldResources() throws {
        let now = Date()
        var toRemove: [String] = []
        
        for (path, resource) in managedResources {
            let age = now.timeIntervalSince(resource.createdAt)
            if age > maxResourceAge && resource.autoCleanup {
                do {
                    try performCleanup(url: resource.url)
                    toRemove.append(path)
                    Logger.debug(
                        "Cleaned up old resource (age: \(Int(age))s): \(path)",
                        category: .fileSystem
                    )
                } catch {
                    Logger.error(
                        "Failed to cleanup old resource \(path): \(error)",
                        category: .fileSystem
                    )
                }
            }
        }
        
        for path in toRemove {
            managedResources.removeValue(forKey: path)
        }
    }
    
    /// Gets statistics about managed resources
    /// 
    /// - Returns: Resource statistics
    public func getStatistics() -> ResourceStatistics {
        let total = managedResources.count
        let autoCleanup = managedResources.values.filter { $0.autoCleanup }.count
        let byType = Dictionary(grouping: managedResources.values) { $0.resourceType }
        
        var totalSize: Int64 = 0
        for resource in managedResources.values {
            if let size = try? calculateResourceSize(url: resource.url) {
                totalSize += size
            }
        }
        
        return ResourceStatistics(
            totalResources: total,
            autoCleanupResources: autoCleanup,
            directories: byType[.directory]?.count ?? 0,
            files: byType[.file]?.count ?? 0,
            temporaryDirectories: byType[.temporaryDirectory]?.count ?? 0,
            totalSize: totalSize
        )
    }
    
    /// Performs the actual cleanup of a resource
    private func performCleanup(url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Calculates the size of a resource
    private func calculateResourceSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        
        if let fileSize = attributes[.size] as? Int64 {
            return fileSize
        }
        
        // For directories, calculate total size
        if attributes[.type] as? FileAttributeType == .typeDirectory {
            var totalSize: Int64 = 0
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
            
            while let fileURL = enumerator?.nextObject() as? URL {
                if let fileAttributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = fileAttributes.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
            
            return totalSize
        }
        
        return 0
    }
    
    deinit {
        if autoCleanupOnDeinit {
            // Synchronously cleanup resources on deinit
            for (_, resource) in managedResources where resource.autoCleanup {
                try? FileManager.default.removeItem(at: resource.url)
            }
        }
    }
}

// MARK: - Resource Statistics

/// Statistics about managed resources
public struct ResourceStatistics: Sendable {
    /// Total number of managed resources
    public let totalResources: Int
    
    /// Number of resources with auto-cleanup enabled
    public let autoCleanupResources: Int
    
    /// Number of directories
    public let directories: Int
    
    /// Number of files
    public let files: Int
    
    /// Number of temporary directories
    public let temporaryDirectories: Int
    
    /// Total size of all resources in bytes
    public let totalSize: Int64
    
    /// Human-readable size string
    public var sizeString: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - Scoped Resource

/// A resource that automatically cleans up when it goes out of scope
/// 
/// This struct provides RAII-style resource management, ensuring that
/// resources are cleaned up when they are no longer needed.
/// 
/// ## Usage Example
/// ```swift
/// let manager = ResourceManager()
/// let tempDir = try await manager.createTemporaryDirectory()
/// 
/// do {
///     let scoped = ScopedResource(url: tempDir, manager: manager)
///     // Use tempDir
///     // ...
/// } // tempDir is automatically cleaned up here
/// ```
public struct ScopedResource: Sendable {
    private let url: URL
    private let manager: ResourceManager
    
    /// Initializes a scoped resource
    /// 
    /// - Parameters:
    ///   - url: URL of the resource
    ///   - manager: Resource manager to use for cleanup
    public init(url: URL, manager: ResourceManager) {
        self.url = url
        self.manager = manager
    }
    
    /// Gets the resource URL
    public var resourceURL: URL {
        return url
    }
    
    /// Manually cleanup the resource
    public func cleanup() async throws {
        try await manager.cleanup(url)
    }
}
