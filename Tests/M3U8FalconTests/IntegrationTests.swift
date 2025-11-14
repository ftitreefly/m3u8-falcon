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
import XCTest

final class IntegrationTests: XCTestCase {
    
    private var container: DependencyContainer!
    private var configuration: DIConfiguration!
    private var mockNetworkClient: MockNetworkClient!
    private var commandExecutor: CommandExecutorProtocol!
    private var downloader: M3U8DownloaderProtocol!
    private var parserService: M3U8ParserServiceProtocol!
    private var fileSystem: FileSystemServiceProtocol!
    private var tempDirectory: URL!
    
    override func setUpWithError() throws {
        configuration = DIConfiguration(maxConcurrentDownloads: 4, downloadTimeout: 5, resourceTimeout: 10)
        container = DependencyContainer()
        container.configure(with: configuration)
        
        mockNetworkClient = MockNetworkClient()
        M3U8TestFixtures.registerAllFixtures(on: mockNetworkClient)
        
        commandExecutor = NoopCommandExecutor()
        
        let registeredNetworkClient = mockNetworkClient!
        let registeredCommandExecutor = commandExecutor!
        
        container.registerSingleton(NetworkClientProtocol.self) { registeredNetworkClient }
        container.registerSingleton(CommandExecutorProtocol.self) { registeredCommandExecutor }
        
        downloader = try container.resolve(M3U8DownloaderProtocol.self)
        parserService = try container.resolve(M3U8ParserServiceProtocol.self)
        fileSystem = try container.resolve(FileSystemServiceProtocol.self)
        tempDirectory = try fileSystem.createTemporaryDirectory(nil)
    }
    
    override func tearDownWithError() throws {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDirectory = nil
        downloader = nil
        parserService = nil
        mockNetworkClient = nil
        container = nil
    }
    
    // MARK: - Downloader + Parser Integration
    
    func testDownloaderAndParserIntegration() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        let result = try parserService.parseContent(
            content,
            baseURL: M3U8TestFixtures.baseURL,
            type: .master
        )
        
        guard case .master(let playlist) = result else {
            return XCTFail("Expected master playlist result")
        }
        
        XCTAssertEqual(playlist.tags.streamTags.count, 1)
        XCTAssertEqual(playlist.tags.streamTags.first?.bandwidth, 150_000)
        XCTAssertEqual(playlist.tags.streamTags.first?.resolution, "640x360")
    }
    
    func testDownloaderProducesMediaPlaylistSegments() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.mediaPlaylistURL)
        let result = try parserService.parseContent(
            content,
            baseURL: M3U8TestFixtures.baseURL,
            type: .media
        )
        
        guard case .media(let playlist) = result else {
            return XCTFail("Expected media playlist result")
        }
        
        XCTAssertEqual(playlist.tags.mediaSegments.count, 3)
        XCTAssertTrue(playlist.tags.mediaSegments.contains { $0.uri == "segment0.ts" })
    }
    
    // MARK: - File System Integration
    
    func testSegmentDownloadsWriteToDisk() async throws {
        let headers = [
            "User-Agent": "IntegrationTests",
            "Accept": "*/*"
        ]
        
        try await downloader.downloadSegments(
            at: M3U8TestFixtures.segmentURLs,
            to: tempDirectory,
            headers: headers
        )
        
        for (url, data) in M3U8TestFixtures.mediaSegments {
            let fileURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
            XCTAssertTrue(fileSystem.fileExists(at: fileURL))
            XCTAssertEqual(try Data(contentsOf: fileURL), data)
        }
    }
    
    func testDownloaderPropagatesNetworkErrors() async throws {
        do {
            _ = try await downloader.downloadContent(from: M3U8TestFixtures.unreachableURL)
            XCTFail("Expected URLError")
        } catch {
            XCTAssertTrue(error is URLError, "Expected URLError, got \(error)")
        }
    }
    
    // MARK: - Dependency Overrides
    
    func testContainerResolvesOverriddenNetworkClient() throws {
        let resolved = try container.resolve(NetworkClientProtocol.self)
        XCTAssertTrue((resolved as AnyObject) === mockNetworkClient)
    }
    
    // MARK: - Extractor Registry Integration
    
    func testCustomExtractorMetadataPersists() throws {
        let registry = DefaultM3U8ExtractorRegistry(
            defaultExtractor: DefaultM3U8LinkExtractor(networkClient: mockNetworkClient)
        )
        
        let customExtractor = CustomInfoExtractor()
        registry.registerExtractor(customExtractor)
        
        let extractors = registry.getRegisteredExtractors()
        let info = extractors.first { $0.name == "CustomInfoExtractor" }
        
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.version, "3.0.0")
        XCTAssertEqual(info?.supportedDomains, ["custom.com", "test.com"])
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
