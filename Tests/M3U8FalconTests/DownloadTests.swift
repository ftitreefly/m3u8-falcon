//
//  DownloadTests.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/9.
//

import Foundation
import XCTest

@testable import M3U8Falcon

final class DownloadTests: XCTestCase {
    
    var testContainer: DependencyContainer!
    var tempDirectory: URL!
    var fileSystem: FileSystemServiceProtocol!
    var httpSystem: M3U8DownloaderProtocol!
    
    // Real M3U8 URLs for testing
    let testM3U8URLs = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"
    ]
    
    override func setUpWithError() throws {
        // Create dependency injection container
        testContainer = DependencyContainer()
        testContainer.configure(with: DIConfiguration.performanceOptimized())
        Logger.configure(.production())
        
        fileSystem = try testContainer.resolve(FileSystemServiceProtocol.self)
        tempDirectory = try fileSystem.createTemporaryDirectory(nil)
        
        httpSystem = try testContainer.resolve(M3U8DownloaderProtocol.self)
    }
    
    override func tearDownWithError() throws {

        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        testContainer = nil
    }

    // MARK: - Helpers
    private func canReachAppleTestServer(timeoutSeconds: TimeInterval = 5) async -> Bool {
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/fileSequence0.ts") else {
            return false
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            _ = try await session.data(for: request)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Basic Download Tests
    
    /// Test performance optimized configuration
    func testPerformanceOptimizedConfiguration() throws {
        XCTAssertNotNil(testContainer, "Test container should exist")

        guard let config = try? testContainer.resolve(DIConfiguration.self) else {
            XCTFail("Configuration should not be nil")
            return
        }

        XCTAssertGreaterThan(config.maxConcurrentDownloads, 8, "Performance optimization config should have higher concurrent downloads")
        XCTAssertGreaterThan(config.downloadTimeout, 0, "Download timeout should be greater than 0")
    }
    
    func testDownloadContentFromValidURL() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        let testURL = URL(string: testM3U8URLs.first!)!
        
        do {
            let content = try await httpSystem.downloadContent(from: testURL)
            
            // Verify returned content
            XCTAssertFalse(content.isEmpty, "Downloaded content should not be empty")
            XCTAssertTrue(content.contains("fileSequence0.ts"), "Content should contain expected response")
            
            // Successfully downloaded content
        } catch {
            XCTFail("Download failed: \(error)")
        }
    }
    
    // MARK: - M3U8 Playlist Download Tests
    
    func testDownloadM3U8Playlist() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Test downloading real M3U8 playlists
        for (_, urlString) in testM3U8URLs.enumerated() {
            guard let url = URL(string: urlString) else {
                XCTFail("Invalid test URL: \(urlString)")
                continue
            }
            
            let content = try await httpSystem.downloadContent(from: url)
            XCTAssertTrue(content.hasPrefix("#EXTM3U"), "Content should be valid M3U8 format")
            XCTAssertTrue(content.contains("#EXTINF") || content.contains("#EXT-X-STREAM-INF"), "Content should contain media segment info")
        }
    }
    
    // MARK: - Video Segment Download Tests
    
    func testDownloadVideoSegments() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Test downloading video segments
        
        // Create test video segment URLs - use small files to avoid long downloads
        let segmentBaseURL =
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/"
        let testSegmentURLs = [
            URL(string: "\(segmentBaseURL)fileSequence0.ts")!,
            URL(string: "\(segmentBaseURL)fileSequence1.ts")!
        ]
        
        let headers = [
            "User-Agent": "M3U8Falcon-Test/1.0",
            "Accept": "*/*"
        ]
        
        do {
            try await httpSystem.downloadSegments(at: testSegmentURLs, to: tempDirectory, headers: headers)
            let files = try fileSystem.contentsOfDirectory(at: tempDirectory)
            XCTAssertGreaterThan(files.count, 0, "Should have downloaded files")
        } catch {
            XCTFail("Video segment download failed: \(error)")
        }
    }
    
    // MARK: - Simple String Response Concurrent Download Tests
    
    func testSimpleStringResponseConcurrentDownloads() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        let urls = (0..<3).map { _ in URL(string: testM3U8URLs.first!)! }

        let httpSystem = self.httpSystem!
        
        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for url in urls {
                group.addTask {
                    try await httpSystem.downloadContent(from: url)
                }
            }
            
            var downloadedContents: [String] = []
            for try await result in group {
                downloadedContents.append(result)
            }
            return downloadedContents
        }
        
        // Verify results
        XCTAssertEqual(results.count, urls.count, "Should download all URLs")
        for result in results {
            XCTAssertFalse(result.isEmpty, "Downloaded content should not be empty")
        }
    }
    
    // MARK: - Simple Data Response Concurrent Download Tests
    
    func testSimpleSegmentsConcurrentDownloads() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        let segmentBaseURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/"
        let testSegmentURLs = (0..<3).map { URL(string: "\(segmentBaseURL)fileSequence\($0).ts")! }

        let httpSystem = self.httpSystem!
        typealias task =  (name: String, rawData: Data)
        _ = try await withThrowingTaskGroup(of: task.self) { group in
            for url in testSegmentURLs {
                group.addTask {
                    task(
                        name: url.lastPathComponent,
                        rawData: (try await httpSystem.downloadRawData(from: url))
                    )
                }
            }
            
            var downloadedContents: [String] = []
            for try await result in group {
                downloadedContents.append(result.name)
                try result.rawData.write(to: tempDirectory.appendingPathComponent(result.name.appending(".ts")))
            }
            return downloadedContents
        }
    }
    
    // MARK: - File System Integration Tests
    
    func testDownloadToFileSystem() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Test downloading to file system
        let outputFile = tempDirectory.appendingPathComponent("test.json")
        
        do {
            // Download content
            let content = try await httpSystem.downloadContent(from: URL(string: testM3U8URLs.first!)!)
            
            // Write to file
            try content.write(to: outputFile, atomically: true, encoding: .utf8)
            
            // Verify file
            XCTAssertTrue(fileSystem.fileExists(at: outputFile), "File should exist")
            
            let savedContent = try String(contentsOf: outputFile)
            XCTAssertEqual(content, savedContent, "Saved content should match downloaded content")
        } catch {
            XCTFail("File system integration test failed: \(error)")
        }
    }
    
    // MARK: - Timeout Tests
    
    func testDownloadWithTimeout() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Test if timeout configuration is correctly applied
        let customConfig = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 5.0  // 5 second timeout
        )
        
        let customContainer = DependencyContainer()
        customContainer.configure(with: customConfig)
        
        do {
            let content = try await httpSystem.downloadContent(from: URL(string: testM3U8URLs[0])!)
            XCTAssertFalse(content.isEmpty, "Should be able to download content")
            // Timeout test passed
        } catch {
            XCTFail("Timeout test failed: \(error)")
        }
    }
    
    func testDownloadQuickResponse() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Test quick response
        guard let downloader = try? testContainer.resolve(M3U8DownloaderProtocol.self) else {
            XCTFail("Downloader should not be nil")
            return
        }
        let testURL = URL(string: testM3U8URLs[0])!
        
        let startTime = Date()
        do {
            let content = try await downloader.downloadContent(from: testURL)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            
            XCTAssertFalse(content.isEmpty, "Downloaded content should not be empty")
            XCTAssertLessThan(duration, 10.0, "Download should complete within 10 seconds")
            
            // Quick response test passed
        } catch {
            XCTFail("Quick response test failed: \(error)")
        }
    }
}
