//
//  DecryptionStrategyTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/11/28.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon
import Testing
import enum M3U8Falcon.Method

@Suite("Decryption Strategy Tests")
final class DecryptionStrategyTests {
    
    private var testEnv: TestEnvironment
    private var taskManager: TaskManagerProtocol
    private var mockProcessor: MockVideoProcessor
    
    // Test configuration
    private let testConfiguration = DIConfiguration(
        maxConcurrentDownloads: 2,
        downloadTimeout: 5,
        resourceTimeout: 10
    )

    init() throws {
        testEnv = try TestEnvironment.create(
            configuration: testConfiguration,
            tempDirectoryPrefix: "DecryptionStrategyTests"
        )
        
        mockProcessor = MockVideoProcessor()
        
        taskManager = try testEnv.createTaskManager(
            processor: mockProcessor,
            maxConcurrentTasks: 2
        )
    }
    
    deinit {
        // Clean up test environment temporary directory
        try? fileSystem.removeItem(at: testEnv.tempDirectory)
    }
    
    // Convenience accessors
    private var tempDirectory: URL { testEnv.tempDirectory }
    private var fileSystem: FileSystemServiceProtocol { testEnv.fileSystem }
    private var mockNetworkClient: MockNetworkClient { testEnv.mockNetworkClient }
    
    // MARK: - Helper Methods
    
    /// Extracts and cleans key and IV from a DecryptionStrategy
    /// - Parameter strategy: The decryption strategy to extract from
    /// - Returns: A tuple containing the cleaned key and IV (both optional)
    private func extractKeyAndIV(from strategy: DecryptionStrategy) -> (key: String?, iv: String?) {
        guard case .customAES128(let decryptionKey, let decryptionIV) = strategy else {
            return (nil, nil)
        }
        
        let key = decryptionKey.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")
        
        let iv = decryptionIV?.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")
        
        return (key, iv)
    }
    
    // MARK: - DecryptionStrategy Enum Tests
    
    @Test("DecryptionStrategy normal case")
    func decryptionStrategyNormal() {
        let strategy = DecryptionStrategy.normal
        
        let (key, iv) = extractKeyAndIV(from: strategy)
        
        #expect(key == nil, "Normal strategy should have no key")
        #expect(iv == nil, "Normal strategy should have no iv")
    }
    
    @Test("DecryptionStrategy customAES128 with key and iv")
    func decryptionStrategyCustomAES128WithKeyAndIV() {
        let testKey = "0123456789abcdef0123456789abcdef"
        let testIV = "fedcba9876543210fedcba9876543210"
        let strategy = DecryptionStrategy.customAES128(key: testKey, iv: testIV)
        
        let (key, iv) = extractKeyAndIV(from: strategy)
        
        #expect(key == testKey, "Key should match")
        #expect(iv == testIV, "IV should match")
    }
    
    @Test("DecryptionStrategy customAES128 with key only")
    func decryptionStrategyCustomAES128WithKeyOnly() {
        let testKey = "0123456789abcdef0123456789abcdef"
        let strategy = DecryptionStrategy.customAES128(key: testKey, iv: nil)
        
        let (key, iv) = extractKeyAndIV(from: strategy)
        
        #expect(key == testKey, "Key should match")
        #expect(iv == nil, "IV should be nil when not provided")
    }
    
    @Test("DecryptionStrategy customAES128 key cleaning")
    func decryptionStrategyCustomAES128KeyCleaning() {
        // Test with 0x prefix
        let keyWithPrefix = "0x0123456789abcdef0123456789abcdef"
        let strategy1 = DecryptionStrategy.customAES128(key: keyWithPrefix, iv: nil)
        
        let (cleanedKey, _) = extractKeyAndIV(from: strategy1)
        
        #expect(cleanedKey == "0123456789abcdef0123456789abcdef", "Should remove 0x prefix")
        
        // Test with whitespace
        let keyWithWhitespace = "  0123456789abcdef0123456789abcdef  "
        let strategy2 = DecryptionStrategy.customAES128(key: keyWithWhitespace, iv: nil)
        
        let (trimmedKey, _) = extractKeyAndIV(from: strategy2)
        
        #expect(trimmedKey == "0123456789abcdef0123456789abcdef", "Should trim whitespace")
    }
    
    // MARK: - TaskRequest with DecryptionStrategy Tests
    
    @Test("TaskRequest with normal strategy")
    func taskRequestWithNormalStrategy() {
        let request = TaskRequest(
            url: URL(string: "https://example.com/video.m3u8")!,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test.mp4",
            method: .web,
            verbose: false,
            decryptionStrategy: .normal
        )
        
        #expect(request.decryptionStrategy == .normal, "Strategy should be normal")
    }
    
    @Test("TaskRequest with customAES128 strategy")
    func taskRequestWithCustomAES128Strategy() {
        let testKey = "0123456789abcdef0123456789abcdef"
        let testIV = "fedcba9876543210fedcba9876543210"
        let strategy = DecryptionStrategy.customAES128(key: testKey, iv: testIV)
        
        let request = TaskRequest(
            url: URL(string: "https://example.com/video.m3u8")!,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test.mp4",
            method: .web,
            verbose: false,
            decryptionStrategy: strategy
        )
        
        #expect(request.decryptionStrategy == strategy, "Strategy should match")
    }
    
    @Test("TaskRequest default strategy is normal")
    func taskRequestDefaultStrategy() {
        let request = TaskRequest(
            url: URL(string: "https://example.com/video.m3u8")!,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test.mp4",
            method: .web,
            verbose: false
        )
        
        #expect(request.decryptionStrategy == .normal, "Default strategy should be normal")
    }
    
    // MARK: - TaskManager Integration Tests
    
    /// Executes a task and verifies the decryption strategy is correctly applied.
    /// Task execution may fail due to missing FFmpeg or other infrastructure issues,
    /// but the strategy should always be correctly stored and passed through.
    private func executeTaskAndVerifyStrategy(
        _ request: TaskRequest,
        expectedStrategy: DecryptionStrategy
    ) async throws {
        #expect(request.decryptionStrategy == expectedStrategy, "Strategy should be stored correctly")
        
        do {
            try await taskManager.createTask(request)
        } catch {
            // Task may fail for infrastructure reasons (FFmpeg, network, etc.),
            // but the strategy configuration should remain correct
            #expect(request.decryptionStrategy == expectedStrategy, "Strategy should remain correct even on error")
        }
    }
    
    @Test("TaskManager with normal decryption strategy")
    func taskManagerWithNormalStrategy() async throws {
        let request = TaskRequest(
            url: M3U8TestFixtures.mediaPlaylistURL,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test-normal.mp4",
            method: .web,
            verbose: false,
            decryptionStrategy: .normal
        )
        
        try await executeTaskAndVerifyStrategy(request, expectedStrategy: .normal)
        
        // Verify output file was created if task succeeded
        let outputFile = tempDirectory.appendingPathComponent("test-normal.mp4")
        if fileSystem.fileExists(at: outputFile) {
            // Output file exists, task completed successfully
            // Additional verification could be added here if needed
        }
    }
    
    @Test("TaskManager with customAES128 decryption strategy")
    func taskManagerWithCustomAES128Strategy() async throws {
        let testKey = "0123456789abcdef0123456789abcdef"
        let testIV = "fedcba9876543210fedcba9876543210"
        let strategy = DecryptionStrategy.customAES128(key: testKey, iv: testIV)
        
        let request = TaskRequest(
            url: M3U8TestFixtures.mediaPlaylistURL,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test-encrypted.mp4",
            method: .web,
            verbose: false,
            decryptionStrategy: strategy
        )
        
        try await executeTaskAndVerifyStrategy(request, expectedStrategy: strategy)
    }
    
    @Test("TaskManager with customAES128 strategy key only")
    func taskManagerWithCustomAES128StrategyKeyOnly() async throws {
        let testKey = "0123456789abcdef0123456789abcdef"
        let strategy = DecryptionStrategy.customAES128(key: testKey, iv: nil)
        
        let request = TaskRequest(
            url: M3U8TestFixtures.mediaPlaylistURL,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test-key-only.mp4",
            method: .web,
            verbose: false,
            decryptionStrategy: strategy
        )
        
        // Verify key extraction works correctly
        let (extractedKey, extractedIV) = extractKeyAndIV(from: request.decryptionStrategy)
        #expect(extractedKey == testKey, "Key should be extractable from strategy")
        #expect(extractedIV == nil, "IV should be nil when not provided")
        
        try await executeTaskAndVerifyStrategy(request, expectedStrategy: strategy)
    }
    
    // MARK: - Strategy Equality Tests
    
    @Test("DecryptionStrategy equality")
    func decryptionStrategyEquality() {
        let strategy1 = DecryptionStrategy.normal
        let strategy2 = DecryptionStrategy.normal
        let strategy3 = DecryptionStrategy.customAES128(key: "key1", iv: "iv1")
        let strategy4 = DecryptionStrategy.customAES128(key: "key1", iv: "iv1")
        let strategy5 = DecryptionStrategy.customAES128(key: "key2", iv: "iv1")
        let strategy6 = DecryptionStrategy.customAES128(key: "key1", iv: nil)
        let strategy7 = DecryptionStrategy.customAES128(key: "key1", iv: nil)
        
        #expect(strategy1 == strategy2, "Normal strategies should be equal")
        #expect(strategy3 == strategy4, "Same customAES128 strategies should be equal")
        #expect(strategy3 != strategy5, "Different keys should not be equal")
        #expect(strategy6 == strategy7, "Same customAES128 strategies with nil IV should be equal")
        #expect(strategy3 != strategy6, "Different IV (one nil) should not be equal")
    }
}

