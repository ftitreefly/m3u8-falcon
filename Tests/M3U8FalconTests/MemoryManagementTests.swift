//
//  MemoryManagementTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon
import Testing

/// Tests for memory management components
@Suite("Memory Management Tests")
final class MemoryManagementTests {
    
    // MARK: - Resource Manager Tests
    
    @Test("Resource manager creates temporary directory")
    func resourceManagerCreatesTemporaryDirectory() async throws {
        let fileSystem = DefaultFileSystemService()
        let manager = ResourceManager(fileSystem: fileSystem)
        
        let tempDir = try await manager.createTemporaryDirectory(prefix: "test")
        #expect(fileSystem.fileExists(at: tempDir))
        
        try await manager.cleanup(tempDir)
        #expect(!fileSystem.fileExists(at: tempDir))
    }
    
    @Test("Resource manager auto cleanup")
    func resourceManagerAutoCleanup() async throws {
        let fileSystem = DefaultFileSystemService()
        let tempDir: URL
        
        do {
            let manager = ResourceManager(fileSystem: fileSystem, autoCleanupOnDeinit: true)
            tempDir = try await manager.createTemporaryDirectory(prefix: "test")
            #expect(fileSystem.fileExists(at: tempDir))
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!fileSystem.fileExists(at: tempDir))
    }
    
    @Test("Resource manager manual cleanup all")
    func resourceManagerManualCleanupAll() async throws {
        let fileSystem = DefaultFileSystemService()
        let manager = ResourceManager(fileSystem: fileSystem)
        
        let tempDir1 = try await manager.createTemporaryDirectory(prefix: "test1")
        let tempDir2 = try await manager.createTemporaryDirectory(prefix: "test2")
        
        #expect(fileSystem.fileExists(at: tempDir1))
        #expect(fileSystem.fileExists(at: tempDir2))
        
        try await manager.cleanupAll()
        
        #expect(!fileSystem.fileExists(at: tempDir1))
        #expect(!fileSystem.fileExists(at: tempDir2))
    }
    
    @Test("Resource manager statistics")
    func resourceManagerStatistics() async throws {
        let fileSystem = DefaultFileSystemService()
        let manager = ResourceManager(fileSystem: fileSystem)
        
        let dir1 = try await manager.createTemporaryDirectory(prefix: "test1")
        let dir2 = try await manager.createTemporaryDirectory(prefix: "test2")
        
        // Create files in directories to ensure totalSize > 0
        let file1 = dir1.appendingPathComponent("file1.txt")
        try "test content 1".write(to: file1, atomically: true, encoding: .utf8)
        
        let file2 = dir2.appendingPathComponent("file2.txt")
        try "test content 2".write(to: file2, atomically: true, encoding: .utf8)
        
        let stats = await manager.getStatistics()
        #expect(stats.totalResources == 2)
        #expect(stats.temporaryDirectories == 2)
        #expect(stats.totalSize > 0)
        
        try await manager.cleanupAll()
    }
    
    @Test("Resource manager registration")
    func resourceManagerRegistration() async throws {
        let fileSystem = DefaultFileSystemService()
        let manager = ResourceManager(fileSystem: fileSystem)
        
        let tempFile = fileSystem.temporaryDirectory()
            .appendingPathComponent("test-\(UUID().uuidString).txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        await manager.register(url: tempFile, type: .file, autoCleanup: true)
        
        let stats = await manager.getStatistics()
        #expect(stats.files == 1)
        
        try await manager.cleanup(tempFile)
        #expect(!fileSystem.fileExists(at: tempFile))
    }
    
    // MARK: - Streaming Downloader Tests
    
    @Test("Streaming downloader initialization")
    func streamingDownloaderInitialization() async {
        let fileSystem = DefaultFileSystemService()
        let config = DIConfiguration.performanceOptimized()
        let client = DefaultNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            fileSystem: fileSystem
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            fileSystem: fileSystem,
            bufferSize: 64 * 1024
        )
        
        // Verify downloader was created successfully
        // (If initialization fails, it would throw an error)
        _ = downloader
    }
    
    @Test("Streaming download to file")
    func streamingDownloadToFile() async throws {
        let fileSystem = DefaultFileSystemService()
        let config = DIConfiguration.performanceOptimized()
        let client = DefaultNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            fileSystem: fileSystem
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            fileSystem: fileSystem,
            bufferSize: 8 * 1024
        )
        
        let url = URL(string: "test://mock/bytes/1024")!
        let destination = fileSystem.temporaryDirectory()
            .appendingPathComponent("test-download-\(UUID().uuidString).bin")
        
        try await downloader.downloadToFile(
            url: url,
            destination: destination,
            progressHandler: { _, _ in }
        )
        
        #expect(fileSystem.fileExists(at: destination))
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = attributes[.size] as? Int64
        #expect(fileSize == 1024)
        
        try fileSystem.removeItem(at: destination)
    }
    
    @Test("Streaming download to memory")
    func streamingDownloadToMemory() async throws {
        let fileSystem = DefaultFileSystemService()
        let config = DIConfiguration.performanceOptimized()
        let client = DefaultNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            fileSystem: fileSystem
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            fileSystem: fileSystem
        )
        
        let url = URL(string: "test://mock/bytes/512")!
        
        let data = try await downloader.downloadToMemory(url: url)
        #expect(data.count == 512)
    }
    
    // MARK: - Memory Efficiency Tests
    
    @Test("Memory efficient download")
    func memoryEfficientDownload() async throws {
        let fileSystem = DefaultFileSystemService()
        let config = DIConfiguration.performanceOptimized()
        let client = DefaultNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            fileSystem: fileSystem
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            fileSystem: fileSystem,
            bufferSize: 16 * 1024
        )
        
        let url = URL(string: "test://mock/bytes/102400")!
        let destination = fileSystem.temporaryDirectory()
            .appendingPathComponent("memory-test-\(UUID().uuidString).bin")
        
        try await downloader.downloadToFile(
            url: url,
            destination: destination
        )
        
        #expect(fileSystem.fileExists(at: destination))
        
        try fileSystem.removeItem(at: destination)
    }
}
