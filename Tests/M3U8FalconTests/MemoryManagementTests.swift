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
        let manager = ResourceManager()
        
        let tempDir = try await manager.createTemporaryDirectory(prefix: "test")
        #expect(FileManager.default.fileExists(atPath: tempDir.path))
        
        try await manager.cleanup(tempDir)
        #expect(!FileManager.default.fileExists(atPath: tempDir.path))
    }
    
    @Test("Resource manager auto cleanup")
    func resourceManagerAutoCleanup() async throws {
        let tempDir: URL
        
        do {
            let manager = ResourceManager(autoCleanupOnDeinit: true)
            tempDir = try await manager.createTemporaryDirectory(prefix: "test")
            #expect(FileManager.default.fileExists(atPath: tempDir.path))
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!FileManager.default.fileExists(atPath: tempDir.path))
    }
    
    @Test("Resource manager manual cleanup all")
    func resourceManagerManualCleanupAll() async throws {
        let manager = ResourceManager()
        
        let tempDir1 = try await manager.createTemporaryDirectory(prefix: "test1")
        let tempDir2 = try await manager.createTemporaryDirectory(prefix: "test2")
        
        #expect(FileManager.default.fileExists(atPath: tempDir1.path))
        #expect(FileManager.default.fileExists(atPath: tempDir2.path))
        
        try await manager.cleanupAll()
        
        #expect(!FileManager.default.fileExists(atPath: tempDir1.path))
        #expect(!FileManager.default.fileExists(atPath: tempDir2.path))
    }
    
    @Test("Resource manager statistics")
    func resourceManagerStatistics() async throws {
        let manager = ResourceManager()
        
        _ = try await manager.createTemporaryDirectory(prefix: "test1")
        _ = try await manager.createTemporaryDirectory(prefix: "test2")
        
        let stats = await manager.getStatistics()
        #expect(stats.totalResources == 2)
        #expect(stats.temporaryDirectories == 2)
        #expect(stats.totalSize > 0)
        
        try await manager.cleanupAll()
    }
    
    @Test("Resource manager registration")
    func resourceManagerRegistration() async throws {
        let manager = ResourceManager()
        
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        await manager.register(url: tempFile, type: .file, autoCleanup: true)
        
        let stats = await manager.getStatistics()
        #expect(stats.files == 1)
        
        try await manager.cleanup(tempFile)
        #expect(!FileManager.default.fileExists(atPath: tempFile.path))
    }
    
    // MARK: - Streaming Downloader Tests
    
    @Test("Streaming downloader initialization")
    func streamingDownloaderInitialization() async {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy()
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 64 * 1024
        )
        
        // Verify downloader was created successfully
        // (If initialization fails, it would throw an error)
        _ = downloader
    }
    
    @Test("Streaming download to file")
    func streamingDownloadToFile() async throws {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy()
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 8 * 1024
        )
        
        let url = URL(string: "test://mock/bytes/1024")!
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-download-\(UUID().uuidString).bin")
        
        try await downloader.downloadToFile(
            url: url,
            destination: destination,
            progressHandler: { _, _ in }
        )
        
        #expect(FileManager.default.fileExists(atPath: destination.path))
        
        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = attributes[.size] as? Int64
        #expect(fileSize == 1024)
        
        try FileManager.default.removeItem(at: destination)
    }
    
    @Test("Streaming download to memory")
    func streamingDownloadToMemory() async throws {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy()
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient
        )
        
        let url = URL(string: "test://mock/bytes/512")!
        
        let data = try await downloader.downloadToMemory(url: url)
        #expect(data.count == 512)
    }
    
    // MARK: - Memory Efficiency Tests
    
    @Test("Memory efficient download")
    func memoryEfficientDownload() async throws {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy()
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 16 * 1024
        )
        
        let url = URL(string: "test://mock/bytes/102400")!
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-test-\(UUID().uuidString).bin")
        
        try await downloader.downloadToFile(
            url: url,
            destination: destination
        )
        
        #expect(FileManager.default.fileExists(atPath: destination.path))
        
        try FileManager.default.removeItem(at: destination)
    }
}
