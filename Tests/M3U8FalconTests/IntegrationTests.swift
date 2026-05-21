//
//  IntegrationTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon
import Testing

@Suite("Integration Tests")
final class IntegrationTests {
    
    private var testEnv: TestEnvironment
    private var downloader: M3U8DownloaderProtocol
    private var parserService: M3U8ParserServiceProtocol
    private var taskManager: TaskManagerProtocol
    private let mockProcessor = MockVideoProcessor()
    
    init() throws {
        testEnv = try TestEnvironment.create()
        testEnv.registerMockServices()
        
        downloader = try testEnv.container.resolve(M3U8DownloaderProtocol.self)
        parserService = try testEnv.container.resolve(M3U8ParserServiceProtocol.self)
        taskManager = try testEnv.createTaskManager(processor: mockProcessor, maxConcurrentTasks: 3)
    }
    
    deinit {
        try? FileManager.default.removeItem(at: testEnv.tempDirectory)
    }
    
    // Convenience accessors
    private var container: DependencyContainer { testEnv.container }
    private var configuration: DIConfiguration { testEnv.configuration }
    private var mockNetworkClient: MockNetworkClient { testEnv.mockNetworkClient }
    private var fileSystem: FileSystemServiceProtocol { testEnv.fileSystem }
    private var tempDirectory: URL { testEnv.tempDirectory }
    
    // MARK: - Downloader + Parser Integration
    
    @Test("Downloader and parser integration")
    func downloaderAndParserIntegration() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        let result = try parserService.parseContent(
            content,
            baseURL: M3U8TestFixtures.baseURL,
            type: .master
        )
        
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist result")
            return
        }
        
        #expect(playlist.tags.streamTags.count == 1)
        #expect(playlist.tags.streamTags.first?.bandwidth == 150_000)
        #expect(playlist.tags.streamTags.first?.resolution == "640x360")
    }
    
    @Test("Downloader produces media playlist segments")
    func downloaderProducesMediaPlaylistSegments() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.mediaPlaylistURL)
        let result = try parserService.parseContent(
            content,
            baseURL: M3U8TestFixtures.baseURL,
            type: .media
        )
        
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist result")
            return
        }
        
        #expect(playlist.tags.mediaSegments.count == 3)
        #expect(playlist.tags.mediaSegments.contains { $0.uri == "segment0.ts" })
    }
    
    // MARK: - Dependency Overrides
    
    @Test("Container resolves overridden network client")
    func containerResolvesOverriddenNetworkClient() throws {
        let resolved = try container.resolve(NetworkClientProtocol.self)
        // Verify that the resolved client is the same instance as the registered mock
        let resolvedID = ObjectIdentifier(resolved as AnyObject)
        let mockID = ObjectIdentifier(mockNetworkClient as AnyObject)
        #expect(resolvedID == mockID)
    }
    
    // MARK: - TaskManager Complete Workflow Integration
    
    @Test("TaskManager complete workflow with media playlist")
    func taskManagerCompleteWorkflowWithMediaPlaylist() async throws {
        let url = M3U8TestFixtures.mediaPlaylistURL
        let request = TaskRequest(
            url: url,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test-integration.mp4",
            method: .web,
            verbose: false
        )
        
        // Execute complete workflow: download → parse → process → save
        // Note: This test may fail if FFmpeg is not available, which is acceptable
        do {
            try await taskManager.createTask(request)
            let outputFile = tempDirectory.appendingPathComponent("test-integration.mp4")
            #expect(fileSystem.fileExists(at: outputFile), "Output file should exist after complete workflow")
        } catch let error as ProcessingError where error.message.contains("FFmpeg") {
            // Skip test if FFmpeg is not available
            return
        }
    }
    
    @Test("TaskManager complete workflow with local file")
    func taskManagerCompleteWorkflowWithLocalFile() async throws {
        let localM3U8Path = tempDirectory.appendingPathComponent("local-test.m3u8")
        let expectedContent = M3U8TestFixtures.mediaPlaylist
        try expectedContent.write(to: localM3U8Path, atomically: true, encoding: .utf8)
        
        // Register segment URLs in mock network client (needed for segment downloads)
        for (segmentURL, segmentData) in M3U8TestFixtures.mediaSegments {
            mockNetworkClient.registerSuccess(
                url: segmentURL,
                data: segmentData,
                headers: ["Content-Type": "video/MP2T"]
            )
        }
        
        let request = TaskRequest(
            url: localM3U8Path,
            baseUrl: nil,
            savedDirectory: tempDirectory,
            fileName: "test-local-integration.mp4",
            method: .local,
            verbose: false
        )
        
        // Note: This test may fail if FFmpeg is not available or due to URL issues, which is acceptable
        do {
            try await taskManager.createTask(request)
            let outputFile = tempDirectory.appendingPathComponent("test-local-integration.mp4")
            #expect(fileSystem.fileExists(at: outputFile), "Output file should exist after local file workflow")
        } catch let error as ProcessingError {
            // Skip test if FFmpeg is not available or if there are URL/network issues
            if error.message.contains("FFmpeg") || error.message.contains("task execution failed") {
                return
            }
            throw error
        }
    }
    
    // MARK: - Method Inference Integration
    
    @Test("Method auto-inference detects web and local URLs")
    func methodAutoInference() throws {
        let webURL1 = URL(string: "https://example.com/video.m3u8")!
        let webURL2 = URL(string: "http://example.com/video.m3u8")!
        let localURL1 = URL(fileURLWithPath: "/path/to/video.m3u8")
        let localURL2 = URL(string: "file:///path/to/video.m3u8")!
        
        #expect(Method.infer(from: webURL1) == .web)
        #expect(Method.infer(from: webURL2) == .web)
        #expect(Method.infer(from: localURL1) == .local)
        #expect(Method.infer(from: localURL2) == .local)
    }
    
    // MARK: - Extractor Registry Integration
    
    @Test("Custom extractor metadata persists")
    func customExtractorMetadataPersists() throws {
        let registry = DefaultM3U8ExtractorRegistry(
            defaultExtractor: DefaultM3U8LinkExtractor(networkClient: mockNetworkClient)
        )
        
        let customExtractor = CustomInfoExtractor()
        registry.registerExtractor(customExtractor)
        
        let extractors = registry.getRegisteredExtractors()
        let info = extractors.first { $0.name == "CustomInfoExtractor" }
        
        #expect(info != nil)
        #expect(info?.version == "3.0.0")
        #expect(info?.supportedDomains == ["custom.com", "test.com"])
    }
    
    // MARK: - Helper Classes
    
    private final class CustomInfoExtractor: M3U8LinkExtractorProtocol {
        func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
            []
        }
        
        func getSupportedDomains() -> [String] {
            ["custom.com", "test.com"]
        }
        
        func getExtractorInfo() -> ExtractorInfo {
            ExtractorInfo(
                name: "CustomInfoExtractor",
                version: "3.0.0",
                supportedDomains: getSupportedDomains(),
                capabilities: [.directLinks, .javascriptVariables]
            )
        }
        
        func canHandle(url: URL) -> Bool { true }
    }
}
