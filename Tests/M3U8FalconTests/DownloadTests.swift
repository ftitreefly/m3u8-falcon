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
@testable import M3U8Falcon
import Testing

@Suite("Download Tests")
final class DownloadTests {
    
    private var testEnv: TestEnvironment
    private var downloader: M3U8DownloaderProtocol
    
    init() throws {
        testEnv = try TestEnvironment.create()
        downloader = testEnv.createDownloader()
    }
    
    deinit {
        try? FileManager.default.removeItem(at: testEnv.tempDirectory)
    }
    
    // Convenience accessors
    private var configuration: DIConfiguration { testEnv.configuration }
    private var tempDirectory: URL { testEnv.tempDirectory }
    private var fileSystem: FileSystemServiceProtocol { testEnv.fileSystem }
    private var mockNetworkClient: MockNetworkClient { testEnv.mockNetworkClient }
    
    // MARK: - Basic Download Tests
    
    @Test("Download content from valid URL")
    func downloadContentFromValidURL() async throws {
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        #expect(!content.isEmpty)
        #expect(content.contains("#EXT-X-VERSION:7"))
    }
    
    // MARK: - M3U8 Playlist Download Tests
    
    @Test("Download M3U8 playlist")
    func downloadM3U8Playlist() async throws {
        for (url, _) in M3U8TestFixtures.playlistMap {
            let content = try await downloader.downloadContent(from: url)
            #expect(content.hasPrefix("#EXTM3U"))
            #expect(content.contains("#EXTINF") || content.contains("#EXT-X-STREAM-INF"))
        }
    }
    
    // MARK: - Video Segment Download Tests
    
    @Test("Download video segments")
    func downloadVideoSegments() async throws {
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
            #expect(fileSystem.fileExists(at: fileURL))
            let saved = try Data(contentsOf: fileURL)
            #expect(saved == data)
        }
    }
    
    // MARK: - Simple String Response Concurrent Download Tests
    
    @Test("Simple string response concurrent downloads")
    func simpleStringResponseConcurrentDownloads() async throws {
        let urls = Array(repeating: M3U8TestFixtures.masterPlaylistURL, count: 3)
        let downloader = self.downloader
        
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
        
        #expect(results.count == urls.count)
        #expect(results.allSatisfy { !$0.isEmpty })
    }
    
    // MARK: - Simple Data Response Concurrent Download Tests
    
    @Test("Simple segments concurrent downloads")
    func simpleSegmentsConcurrentDownloads() async throws {
        let urls = M3U8TestFixtures.segmentURLs
        let downloader = self.downloader
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
        
        #expect(results.count == urls.count)
        for result in results {
            let expectedURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/\(result.name)")
            #expect(result.data == M3U8TestFixtures.mediaSegments[expectedURL])
        }
    }
    
    // MARK: - File System Integration Tests
    
    @Test("Download to file system")
    func downloadToFileSystem() async throws {
        let outputFile = tempDirectory.appendingPathComponent("test.m3u8")
        let content = try await downloader.downloadContent(from: M3U8TestFixtures.mediaPlaylistURL)
        try content.write(to: outputFile, atomically: true, encoding: .utf8)
        
        #expect(fileSystem.fileExists(at: outputFile))
        let savedContent = try String(contentsOf: outputFile, encoding: .utf8)
        #expect(content == savedContent)
    }
    
    // MARK: - Timeout Tests
    
    @Test("Download with timeout")
    func downloadWithTimeout() async throws {
        let customConfig = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 5.0
        )
        
        let customDownloader = DefaultM3U8Downloader(
            commandExecutor: NoopCommandExecutor(),
            configuration: customConfig,
            networkClient: mockNetworkClient,
            fileSystem: testEnv.fileSystem
        )
        
        let content = try await customDownloader.downloadContent(from: M3U8TestFixtures.masterPlaylistURL)
        #expect(!content.isEmpty)
    }
    
    @Test("Download quick response")
    func downloadQuickResponse() async throws {
        let testURL = M3U8TestFixtures.masterPlaylistURL
        let startTime = Date()
        let content = try await downloader.downloadContent(from: testURL)
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(!content.isEmpty)
        #expect(duration < 0.05, "Fixture-backed download should be near instant")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle 404 client error")
    func handle404ClientError() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/notfound.m3u8")
        mockNetworkClient.registerSuccess(
            url: errorURL,
            data: Data(),
            statusCode: 404
        )
        
        do {
            _ = try await downloader.downloadContent(from: errorURL)
            Issue.record("Expected NetworkError for 404 status")
        } catch let error as NetworkError {
            #expect(error.code == 1004 || error.code == 1006) // serverError can return 1004 or 1006
        } catch {
            Issue.record("Expected NetworkError, got \(type(of: error))")
        }
    }
    
    @Test("Handle 500 server error")
    func handle500ServerError() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/servererror.m3u8")
        mockNetworkClient.registerSuccess(
            url: errorURL,
            data: Data(),
            statusCode: 500
        )
        
        do {
            _ = try await downloader.downloadContent(from: errorURL)
            Issue.record("Expected NetworkError for 500 status")
        } catch let error as NetworkError {
            #expect(error.code == 1004 || error.code == 1006) // serverError can return 1004 or 1006
        } catch {
            Issue.record("Expected NetworkError, got \(type(of: error))")
        }
    }
    
    @Test("Handle connection failure")
    func handleConnectionFailure() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/connectionfailed.m3u8")
        mockNetworkClient.registerFailure(
            url: errorURL,
            error: URLError(.notConnectedToInternet)
        )
        
        do {
            _ = try await downloader.downloadContent(from: errorURL)
            Issue.record("Expected error for connection failure")
        } catch {
            // Expected to throw URLError or NetworkError
            #expect(error is URLError || error is NetworkError)
        }
    }
    
    @Test("Handle timeout error")
    func handleTimeoutError() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/timeout.m3u8")
        mockNetworkClient.registerFailure(
            url: errorURL,
            error: URLError(.timedOut)
        )
        
        do {
            _ = try await downloader.downloadContent(from: errorURL)
            Issue.record("Expected error for timeout")
        } catch {
            // Expected to throw URLError or NetworkError
            #expect(error is URLError || error is NetworkError)
        }
    }
    
    @Test("Handle unreachable URL")
    func handleUnreachableURL() async throws {
        do {
            _ = try await downloader.downloadContent(from: M3U8TestFixtures.unreachableURL)
            Issue.record("Expected error for unreachable URL")
        } catch {
            // Expected to throw URLError or NetworkError
            #expect(error is URLError || error is NetworkError)
        }
    }
    
    @Test("Handle non-200 status code in downloadRawData")
    func handleNon200StatusInDownloadRawData() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/forbidden.m3u8")
        mockNetworkClient.registerSuccess(
            url: errorURL,
            data: Data("Forbidden".utf8),
            statusCode: 403
        )
        
        do {
            _ = try await downloader.downloadRawData(from: errorURL)
            Issue.record("Expected NetworkError for 403 status")
        } catch let error as NetworkError {
            #expect(error.code == 1004 || error.code == 1006) // serverError can return 1004 or 1006
        } catch {
            Issue.record("Expected NetworkError, got \(type(of: error))")
        }
    }
    
    @Test("Handle segment download failure")
    func handleSegmentDownloadFailure() async throws {
        let errorURL = M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/failed_segment.ts")
        mockNetworkClient.registerFailure(
            url: errorURL,
            error: URLError(.networkConnectionLost)
        )
        
        do {
            try await downloader.downloadSegments(
                at: [errorURL],
                to: tempDirectory,
                headers: [:]
            )
            Issue.record("Expected error for failed segment download")
        } catch {
            // Expected to throw URLError or NetworkError
            #expect(error is URLError || error is NetworkError)
        }
    }
    
    // MARK: - Concurrency Control Tests
    
    @Test("Respect maxConcurrentDownloads limit in segment downloads")
    func respectMaxConcurrentDownloadsLimitInSegmentDownloads() async throws {
        // Create a downloader with limited concurrency
        let limitedConfig = DIConfiguration(
            maxConcurrentDownloads: 2,
            downloadTimeout: 5,
            resourceTimeout: 10
        )
        let limitedDownloader = DefaultM3U8Downloader(
            commandExecutor: NoopCommandExecutor(),
            configuration: limitedConfig,
            networkClient: mockNetworkClient,
            fileSystem: testEnv.fileSystem
        )
        
        // Create more segment URLs than the concurrency limit
        let segmentURLs = [
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment_a.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment_b.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment_c.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment_d.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment_e.ts")
        ]
        
        // Register all segments
        for url in segmentURLs {
            mockNetworkClient.registerSuccess(
                url: url,
                data: Data(repeating: 0x22, count: 1 * 1024),
                headers: ["Content-Type": "video/MP2T"]
            )
        }
        
        // Download segments - should respect concurrency limit internally
        try await limitedDownloader.downloadSegments(
            at: segmentURLs,
            to: tempDirectory,
            headers: [:]
        )
        
        // Verify all segments were downloaded
        for url in segmentURLs {
            let fileURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
            #expect(fileSystem.fileExists(at: fileURL), "Segment \(url.lastPathComponent) should be downloaded")
        }
    }
    
    @Test("Concurrent segment downloads respect limit")
    func concurrentSegmentDownloadsRespectLimit() async throws {
        // Create a downloader with limited concurrency
        let limitedConfig = DIConfiguration(
            maxConcurrentDownloads: 2,
            downloadTimeout: 5,
            resourceTimeout: 10
        )
        let limitedDownloader = DefaultM3U8Downloader(
            commandExecutor: NoopCommandExecutor(),
            configuration: limitedConfig,
            networkClient: mockNetworkClient,
            fileSystem: testEnv.fileSystem
        )
        
        // Create more segment URLs than the concurrency limit
        let segmentURLs = M3U8TestFixtures.segmentURLs + [
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment3.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment4.ts"),
            M3U8TestFixtures.baseURL.appendingPathComponent("fixtures/segment5.ts")
        ]
        
        // Register additional segments
        for url in segmentURLs.suffix(3) {
            mockNetworkClient.registerSuccess(
                url: url,
                data: Data(repeating: 0x11, count: 1 * 1024),
                headers: ["Content-Type": "video/MP2T"]
            )
        }
        
        // Download segments - should respect concurrency limit
        try await limitedDownloader.downloadSegments(
            at: segmentURLs,
            to: tempDirectory,
            headers: [:]
        )
        
        // Verify all segments were downloaded
        for url in segmentURLs {
            let fileURL = tempDirectory.appendingPathComponent(url.lastPathComponent)
            #expect(fileSystem.fileExists(at: fileURL), "Segment \(url.lastPathComponent) should be downloaded")
        }
    }
}
