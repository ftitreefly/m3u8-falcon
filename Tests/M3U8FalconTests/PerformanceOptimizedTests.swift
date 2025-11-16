//
//  PerformanceOptimized.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/9.
//

import Foundation
@testable import M3U8Falcon
import Testing

@Suite("Performance Optimized Tests")
final class PerformanceOptimizedTests {
    
    private var testContainer: DependencyContainer
    
    init() throws {
        testContainer = DependencyContainer()
        testContainer.configure(with: DIConfiguration.performanceOptimized())
        Logger.configure(.production())
    }
    
    @Test("Basic initialization")
    func basicInitialization() throws {
        // Configure performance optimization settings
        testContainer.configure(with: DIConfiguration.performanceOptimized())
        
        let configuration = try testContainer.resolve(DIConfiguration.self)
        #expect(configuration.maxConcurrentDownloads == 20)
        #expect(configuration.downloadTimeout == 60)
    }
    
    @Test("Configuration validation")
    func configurationValidation() throws {
        // Test custom configuration
        let customConfig = DIConfiguration(
            ffmpegPath: "/usr/local/bin/ffmpeg",
            defaultHeaders: ["User-Agent": "TestAgent"],
            maxConcurrentDownloads: 10,
            downloadTimeout: 60
        )
        
        testContainer.configure(with: customConfig)
        
        let resolvedConfig = try testContainer.resolve(DIConfiguration.self)
        #expect(resolvedConfig.maxConcurrentDownloads == 10)
        #expect(resolvedConfig.downloadTimeout == 60)
        #expect(resolvedConfig.defaultHeaders["User-Agent"] == "TestAgent")
    }
    
    @Test("File system operations")
    func fileSystemOperations() throws {
        let fileSystem = try testContainer.resolve(FileSystemServiceProtocol.self)
        
        let tempDir = try fileSystem.createTemporaryDirectory(nil)
        #expect(fileSystem.fileExists(at: tempDir))
        
        try fileSystem.removeItem(at: tempDir)
        #expect(!fileSystem.fileExists(at: tempDir))
    }
    
    @Test("Command executor creation")
    func commandExecutorCreation() throws {
        let commandExecutor = try testContainer.resolve(CommandExecutorProtocol.self)
        _ = commandExecutor
    }
    
    @Test("Performance optimized configuration")
    func performanceOptimizedConfiguration() {
        let config = DIConfiguration.performanceOptimized()
        
        // Core performance parameters
        #expect(config.maxConcurrentDownloads == 20, "Should have 20 concurrent downloads for performance")
        #expect(config.downloadTimeout == 60, "Should have 60 second download timeout")
        #expect(config.resourceTimeout == 120, "Should have 120 second resource timeout")
        
        // Retry configuration
        #expect(config.retryAttempts == 2, "Should have 2 retry attempts")
        #expect(config.retryBackoffBase == 0.4, "Should have 0.4 second retry backoff base")
        
        // Logging configuration
        #expect(config.logLevel == .error, "Should use error log level for performance")
        
        // HTTP headers validation
        #expect(config.defaultHeaders["User-Agent"] != nil, "Should have User-Agent header")
        #expect(config.defaultHeaders["Accept"] == "*/*", "Should have Accept header")
        #expect(config.defaultHeaders["Accept-Language"] == "en-US,en;q=0.9", "Should have Accept-Language header")
        #expect(config.defaultHeaders["Cache-Control"] == "no-cache", "Should have Cache-Control header")
        #expect(config.defaultHeaders["Connection"] == "keep-alive", "Should have Connection header")
        
        // FFmpeg path (may be nil if not found, but should be tested)
        // The path detection is environment-dependent, so we just verify it's set or nil
        _ = config.ffmpegPath
    }
    
    @Test("Performance optimized configuration all parameters")
    func performanceOptimizedConfigurationAllParameters() {
        let config = DIConfiguration.performanceOptimized()
        
        // Verify all numeric parameters
        #expect(config.maxConcurrentDownloads == 20)
        #expect(config.downloadTimeout == 60.0)
        #expect(config.resourceTimeout == 120.0)
        #expect(config.retryAttempts == 2)
        #expect(config.retryBackoffBase == 0.4)
        
        // Verify log level
        #expect(config.logLevel == .error)
        
        // Verify all required headers are present
        let requiredHeaders = [
            "User-Agent",
            "Accept",
            "Accept-Language",
            "Cache-Control",
            "Connection"
        ]
        
        for header in requiredHeaders {
            #expect(config.defaultHeaders[header] != nil, "Missing required header: \(header)")
        }
        
        // Verify header values match expected performance-optimized values
        #expect(config.defaultHeaders["Accept"] == "*/*")
        #expect(config.defaultHeaders["Accept-Language"] == "en-US,en;q=0.9")
        #expect(config.defaultHeaders["Cache-Control"] == "no-cache")
        #expect(config.defaultHeaders["Connection"] == "keep-alive")
        
        // User-Agent should contain browser-like string
        let userAgent = config.defaultHeaders["User-Agent"] ?? ""
        #expect(userAgent.contains("Mozilla") || userAgent.contains("AppleWebKit"), "User-Agent should be browser-like")
    }
    
    @Test("Dependency container basics")
    func dependencyContainerBasics() throws {
        let container = DependencyContainer()
        
        container.register(String.self) { "test" }
        let result = try container.resolve(String.self)
        #expect(result == "test")
        
        container.registerSingleton(Int.self) { 42 }
        let value1 = try container.resolve(Int.self)
        let value2 = try container.resolve(Int.self)
        #expect(value1 == 42)
        #expect(value2 == 42)
    }
    
    @Test("M3U8 parser service through DI container")
    func m3U8ParserServiceThroughDIContainer() throws {
        // Test that parser service can be resolved through DI container
        // This is different from ParseTests which tests the parser directly
        let parser = try testContainer.resolve(M3U8ParserServiceProtocol.self)
        
        let m3u8Content = """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:10
    #EXT-X-MEDIA-SEQUENCE:0
    #EXTINF:10.0,
    segment1.ts
    #EXTINF:10.0,
    segment2.ts
    #EXT-X-ENDLIST
    """
        
        let baseURL = URL(string: "https://example.com/")!
        let result = try parser.parseContent(m3u8Content, baseURL: baseURL, type: .media)
        
        switch result {
        case .media(let playlist):
            #expect(playlist.tags.mediaSegments.count == 2)
            #expect(playlist.tags.mediaSegments[0].uri == "segment1.ts")
            #expect(playlist.tags.mediaSegments[1].uri == "segment2.ts")
        case .master, .cancelled:
            Issue.record("Expected media playlist")
        }
    }
    
    @Test("FFmpeg path detection in performance optimized configuration")
    func ffmpegPathDetection() {
        let config = DIConfiguration.performanceOptimized()
        
        // FFmpeg path may be nil if not found, which is acceptable
        if let ffmpegPath = config.ffmpegPath {
            // If path is detected, verify it's valid
            #expect(FileManager.default.fileExists(atPath: ffmpegPath), 
                    "FFmpeg path should point to an existing file")
            #expect(FileManager.default.isExecutableFile(atPath: ffmpegPath), 
                    "FFmpeg path should point to an executable file")
        }
        // If nil, that's also acceptable - FFmpeg may not be installed
    }
}
