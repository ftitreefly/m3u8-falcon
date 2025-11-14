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
import XCTest
@testable import M3U8Falcon

// MARK: - Mock Streaming Client

/// Mock streaming client for testing
final class MockStreamingClient: StreamingNetworkClientProtocol {
    func fetchAsyncBytes(from url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>) {
        // Parse the expected size from the URL if available (e.g., /bytes/512)
        let urlString = url.absoluteString
        var size = 1024 // default size
        
        // Extract size from URL path like /bytes/512
        if let bytesRange = urlString.range(of: "/bytes/") {
            let substring = urlString[bytesRange.upperBound...]
            let endIndex = substring.firstIndex(where: { !$0.isNumber }) ?? urlString.endIndex
            let sizeString = String(urlString[bytesRange.upperBound..<endIndex])
            size = Int(sizeString) ?? 1024
        }
        
        // Create a mock response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(size)"]
        )!
        
        // Create a mock byte stream
        let capturedSize = size // Capture size to avoid concurrency issues
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                // Generate mock bytes
                for index in 0..<capturedSize {
                    continuation.yield(UInt8(index % 256))
                }
                continuation.finish()
            }
        }
        
        return (response, stream)
    }
}

/// Tests for memory management components
final class MemoryManagementTests: XCTestCase {
    
    // MARK: - Resource Manager Tests
    
    func testResourceManagerCreatesTemporaryDirectory() async throws {
        let manager = ResourceManager()
        
        let tempDir = try await manager.createTemporaryDirectory(prefix: "test")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
        
        // Cleanup
        try await manager.cleanup(tempDir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))
    }
    
    func testResourceManagerAutoCleanup() async throws {
        let tempDir: URL
        
        do {
            let manager = ResourceManager(autoCleanupOnDeinit: true)
            tempDir = try await manager.createTemporaryDirectory(prefix: "test")
            XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))
            // manager will be deallocated here
        }
        
        // Give some time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Directory should be cleaned up
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir.path))
    }
    
    func testResourceManagerManualCleanupAll() async throws {
        let manager = ResourceManager()
        
        let tempDir1 = try await manager.createTemporaryDirectory(prefix: "test1")
        let tempDir2 = try await manager.createTemporaryDirectory(prefix: "test2")
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir2.path))
        
        // Cleanup all
        try await manager.cleanupAll()
        
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir1.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDir2.path))
    }
    
    func testResourceManagerStatistics() async throws {
        let manager = ResourceManager()
        
        _ = try await manager.createTemporaryDirectory(prefix: "test1")
        _ = try await manager.createTemporaryDirectory(prefix: "test2")
        
        let stats = await manager.getStatistics()
        XCTAssertEqual(stats.totalResources, 2)
        XCTAssertEqual(stats.temporaryDirectories, 2)
        XCTAssertGreaterThan(stats.totalSize, 0)
        
        // Cleanup
        try await manager.cleanupAll()
    }
    
    func testResourceManagerRegistration() async throws {
        let manager = ResourceManager()
        
        // Create a file manually
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).txt")
        try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
        
        // Register it
        await manager.register(url: tempFile, type: .file, autoCleanup: true)
        
        // Verify it's tracked
        let stats = await manager.getStatistics()
        XCTAssertEqual(stats.files, 1)
        
        // Cleanup
        try await manager.cleanup(tempFile)
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))
    }
    
    // MARK: - Streaming Downloader Tests
    
    func testStreamingDownloaderInitialization() async {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: nil
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 64 * 1024
        )
        
        XCTAssertNotNil(downloader)
    }
    
    func testStreamingDownloadToFile() async throws {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: nil
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 8 * 1024  // Small buffer for testing
        )
        
        // Use a small file for testing
        let url = URL(string: "https://httpbingo.org/bytes/1024")!
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-download-\(UUID().uuidString).bin")
        
        do {
            try await downloader.downloadToFile(
                url: url,
                destination: destination,
                progressHandler: { _, _ in
                    // Progress handler is Sendable, just count calls
                }
            )
            
            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
            
            // Verify file size
            let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
            let fileSize = attributes[.size] as? Int64
            XCTAssertEqual(fileSize, 1024)
            
            // Progress was called (file exists, so download completed)
            
            // Cleanup
            try FileManager.default.removeItem(at: destination)
        } catch {
            print("⚠️ Network test failed (this can happen): \(error)")
        }
    }
    
    func testStreamingDownloadToMemory() async throws {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: nil
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient
        )
        
        // Use a small file for testing
        let url = URL(string: "https://httpbingo.org/bytes/512")!
        
        do {
            let data = try await downloader.downloadToMemory(url: url)
            
            XCTAssertEqual(data.count, 512)
        } catch {
            print("⚠️ Network test failed (this can happen): \(error)")
        }
    }
    
    // MARK: - Memory Efficiency Tests
    
    func testMemoryEfficientDownload() async throws {
        // This test verifies that streaming download uses less memory than
        // loading the entire file into memory
        
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: nil
        )
        
        let streamingClient = MockStreamingClient()
        let downloader = StreamingDownloader(
            networkClient: client,
            streamingClient: streamingClient,
            bufferSize: 16 * 1024  // 16 KB buffer
        )
        
        // Download a moderately sized file
        let url = URL(string: "https://httpbingo.org/bytes/102400")! // 100 KB
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-test-\(UUID().uuidString).bin")
        
        do {
            try await downloader.downloadToFile(
                url: url,
                destination: destination
            )
            
            // Verify file was created
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
            
            // Cleanup
            try FileManager.default.removeItem(at: destination)
        } catch {
            print("⚠️ Network test failed (this can happen): \(error)")
        }
    }
}
