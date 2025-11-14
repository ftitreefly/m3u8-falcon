//
//  DownloadTests.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/9.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

@testable import M3U8Falcon

final class DownloadTests: XCTestCase {
    
    private var configuration: DIConfiguration!
    private var tempDirectory: URL!
    private var fileSystem: FileSystemServiceProtocol!
    private var downloader: M3U8DownloaderProtocol!
    private var mockNetworkClient: MockNetworkClient!
    private var commandExecutor: CommandExecutorProtocol!
    
    override func setUpWithError() throws {
        configuration = DIConfiguration(maxConcurrentDownloads: 4, downloadTimeout: 5, resourceTimeout: 10)
        fileSystem = DefaultFileSystemService()
        tempDirectory = try fileSystem.createTemporaryDirectory(nil)
        
        mockNetworkClient = MockNetworkClient()
        M3U8TestFixtures.registerAllFixtures(on: mockNetworkClient)
        
        commandExecutor = NoopCommandExecutor()
        downloader = DefaultM3U8Downloader(
            commandExecutor: commandExecutor,
            configuration: configuration,
            networkClient: mockNetworkClient
        )
    }
    
    override func tearDownWithError() throws {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDirectory = nil
        downloader = nil
        mockNetworkClient = nil
    }
    
    // MARK: - Basic Download Tests
    
    func testPerformanceOptimizedConfiguration() throws {
        let config = DIConfiguration.performanceOptimized()
        XCTAssertGreaterThan(config.maxConcurrentDownloads, 8)
        XCTAssertGreaterThan(config.downloadTimeout, 0)
    }
    
    func testDownloadContentFromValidURL() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        XCTAssertFalse(content.isEmpty)
        XCTAssertTrue(content.contains("#EXT-X-VERSION:7"))
    }
    
    // MARK: - M3U8 Playlist Download Tests
    
    func testDownloadM3U8Playlist() async throws {
        for (url, _) in M3U8TestFixtures.playlistMap {
            let content = try await downloader.downloadContent(from: url)
            XCTAssertTrue(content.hasPrefix("#EXTM3U"))
            XCTAssertTrue(content.contains("#EXTINF") || content.contains("#EXT-X-STREAM-INF"))
        }
    }
    
    // MARK: - Video Segment Download Tests
    
    func testDownloadVideoSegments() async throws {
        let headers = [
            "User-Agent": "M3U8Falcon-Test/1.0",
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
            let saved = try Data(contentsOf: fileURL)
            XCTAssertEqual(saved, data)
        }
    }
    
    // MARK: - Simple String Response Concurrent Download Tests
    
    func testSimpleStringResponseConcurrentDownloads() async throws {
        let urls = Array(repeating: M3U8TestFixtures.masterPlaylistURL, count: 3)
        let downloader = self.downloader!
        
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for url in urls {
                group.addTask {
                    try await downloader.downloadContent(from: url)
                }
            }
            
            var downloadedContents: [String] = []
            for try await result in group {
                downloadedContents.append(result)
            }
            return downloadedContents
        }
        
        XCTAssertEqual(results.count, urls.count)
        XCTAssertTrue(results.allSatisfy { !$0.isEmpty })
    }
    
    // MARK: - Simple Data Response Concurrent Download Tests
    
    func testSimpleSegmentsConcurrentDownloads() async throws {
        let urls = M3U8TestFixtures.segmentURLs
        let downloader = self.downloader!
        typealias TaskResult = (name: String, data: Data)
        let results = try await withThrowingTaskGroup(of: TaskResult.self) { group in
            for url in urls {
                group.addTask {
                    TaskResult(
                        name: url.lastPathComponent,
                        data: try await downloader.downloadRawData(from: url)
                    )
                }
            }
            
            var items: [TaskResult] = []
            for try await result in group {
                items.append(result)
            }
            return items
        }
        
        XCTAssertEqual(results.count, urls.count)
        for result in results {
            let expectedURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/\(result.name)")
            XCTAssertEqual(result.data, M3U8TestFixtures.mediaSegments[expectedURL])
        }
    }
    
    // MARK: - File System Integration Tests
    
    func testDownloadToFileSystem() async throws {
        let outputFile = tempDirectory.appendingPathComponent("test.m3u8")
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.mediaPlaylistURL)
        try content.write(to: outputFile, atomically: true, encoding: .utf8)
        
        XCTAssertTrue(fileSystem.fileExists(at: outputFile))
        let savedContent = try String(contentsOf: outputFile, encoding: .utf8)
        XCTAssertEqual(content, savedContent)
    }
    
    // MARK: - Timeout Tests
    
    func testDownloadWithTimeout() async throws {
        let customConfig = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 5.0
        )
        
        let customDownloader = DefaultM3U8Downloader(
            commandExecutor: commandExecutor,
            configuration: customConfig,
            networkClient: mockNetworkClient
        )
        
        let content = try await customDownloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        XCTAssertFalse(content.isEmpty)
    }
    
    func testDownloadQuickResponse() async throws {
        let testURL = M3U8TestFixtures.masterPlaylistURL
        let startTime = Date()
        let content = try await downloader.downloadContent(from: testURL)
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(content.isEmpty)
        XCTAssertLessThan(duration, 0.05, "Fixture-backed download should be near instant")
    }
}
