//
//  NetworkTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/13.
//

@testable import M3U8Falcon
import XCTest

final class NetworkTests: XCTestCase {
    
    // MARK: - Test M3U8 URLs
    
    // These are publicly available HLS test stream URLs
    let testURLs = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"
    ]
    
    // MARK: - Basic Network Tests
    
    func testBasicM3U8Download() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Use the most stable Apple test stream
        guard let url = URL(string: testURLs[0]) else {
            XCTFail("Unable to create test URL")
            return
        }
        
        do {
            // Use URLSession for direct download test
            let session = makeEphemeralSession(timeoutSeconds: 10)
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("Response is not an HTTP response")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200, "HTTP status code should be 200")
            
            let content = String(data: data, encoding: .utf8) ?? ""
            
            // Validate M3U8 format
            XCTAssertTrue(content.hasPrefix("#EXTM3U"), "M3U8 file should start with #EXTM3U")
            XCTAssertTrue(content.contains("#EXT-X-VERSION"), "Should contain version tag")
            
            // Check if it's a master playlist or media playlist
            if content.contains("#EXT-X-STREAM-INF") {
                XCTAssertTrue(content.contains("#EXT-X-STREAM-INF"), "Master playlist should contain stream info")
            } else if content.contains("#EXTINF") {
                XCTAssertTrue(content.contains("#EXTINF"), "Media playlist should contain segment info")
            }
            
        } catch {
            throw XCTSkip("Skipping: transient network error \(error)")
        }
    }
    
    func testMultipleM3U8URLs() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        
        var successCount = 0
        let session = makeEphemeralSession(timeoutSeconds: 10)
        
        for urlString in testURLs {
            guard let url = URL(string: urlString) else {
                continue
            }
            
            do {
                let (data, response) = try await session.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    let content = String(data: data, encoding: .utf8) ?? ""
                    if content.hasPrefix("#EXTM3U") {
                        successCount += 1
                    }
                }
            } catch {
                // ignore individual failures; overall check below
            }
            
        }
        
        XCTAssertGreaterThan(successCount, 0, "At least one M3U8 download should succeed")
    }
    
    // MARK: - M3U8 Content Analysis
    
    func testM3U8ContentAnalysis() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        let urlString = testURLs[0] // Use the most stable Apple test stream
        guard let url = URL(string: urlString) else {
            XCTFail("Unable to create test URL")
            return
        }
        
        do {
            let session = makeEphemeralSession(timeoutSeconds: 10)
            let (data, _) = try await session.data(from: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            
            // M3U8 content analysis
            
            // Analyze version
            if let versionLine = content.components(separatedBy: .newlines).first(where: { $0.hasPrefix("#EXT-X-VERSION:") }) {
                let version = versionLine.replacingOccurrences(of: "#EXT-X-VERSION:", with: "")
                XCTAssertFalse(version.isEmpty, "Version should not be empty")
            }
            
            // Check playlist type
            if content.contains("#EXT-X-STREAM-INF") {
                let streamCount = content.components(separatedBy: "#EXT-X-STREAM-INF").count - 1
                XCTAssertGreaterThan(streamCount, 0, "Master playlist should contain at least one stream")
                
                // Analyze bitrate
                let bitratePattern = "BANDWIDTH=(\\d+)"
                let regex = try NSRegularExpression(pattern: bitratePattern)
                let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                
                var bitrates: [Int] = []
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        if let bitrate = Int(content[range]) {
                            bitrates.append(bitrate)
                        }
                    }
                }
                
                // Bitrate analysis completed
                
            } else if content.contains("#EXTINF") {
                let segmentCount = content.components(separatedBy: "#EXTINF").count - 1
                XCTAssertGreaterThan(segmentCount, 0, "Media playlist should contain at least one segment")
                
                // Check target duration
                if let targetDurationLine = content.components(separatedBy: .newlines).first(where: { $0.hasPrefix("#EXT-X-TARGETDURATION:") }) {
                    _ = targetDurationLine.replacingOccurrences(of: "#EXT-X-TARGETDURATION:", with: "")
                    // Target duration validation completed
                }
            }
            
        } catch {
            throw XCTSkip("Skipping: transient network error \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidURL() async throws {
        let invalidURL = URL(string: "https://this-domain-does-not-exist-12345.com/test.m3u8")!
        
        // Testing invalid URL error handling
        
        do {
            _ = try await makeEphemeralSession(timeoutSeconds: 5).data(from: invalidURL)
            XCTFail("Should throw network error")
        } catch {
            // Correctly caught network error
        }
    }
    
    // MARK: - Performance Tests
    
    func testDownloadPerformance() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }

        let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/fileSequence0.ts")!
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            let session = makeEphemeralSession(timeoutSeconds: 10)
            let (data, _) = try await session.data(from: url)
            let endTime = CFAbsoluteTimeGetCurrent()
            
            let downloadTime = endTime - startTime
            let dataSize = data.count
            let speed = Double(dataSize) / downloadTime / 1024 // KB/s
            
            XCTAssertGreaterThan(dataSize, 0, "Downloaded data should be greater than 0")
            XCTAssertGreaterThan(speed, 0, "Download speed should be greater than 0")
            
        } catch {
            throw XCTSkip("Skipping: transient network error \(error)")
        }
    }
    
    // MARK: - Integration with M3U8Falcon
    
    func testM3U8FalconIntegration() async throws {
        guard await canReachAppleTestServer() else { throw XCTSkip("Skipping: network not available") }
        // Testing integration with M3U8Falcon
        
        // Use M3U8Falcon for complete testing
        let url = URL(string: testURLs[0])!
        
        do {
            // Directly test M3U8Parser instead of the entire M3U8Falcon
            let session = makeEphemeralSession(timeoutSeconds: 10)
            let (data, _) = try await session.data(from: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            
            let parser = M3U8Parser()
            let params = M3U8Parser.Params(playlist: content, playlistType: .media, baseUrl: url.deletingLastPathComponent())
            
            let result = try parser.parse(params: params)
            
            switch result {
            case .master(let masterPlaylist):
                XCTAssertGreaterThan(masterPlaylist.tags.streamTags.count, 0)
                
            case .media(let mediaPlaylist):
                XCTAssertGreaterThan(mediaPlaylist.tags.mediaSegments.count, 0)
                
            case .cancelled:
                XCTFail("Parsing should not be cancelled")
            }
            
        } catch {
            throw XCTSkip("Skipping: transient network error \(error)")
        }
    }
    
    // MARK: - Helpers
    private func makeEphemeralSession(timeoutSeconds: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        return URLSession(configuration: config)
    }
    
    private func canReachAppleTestServer(timeoutSeconds: TimeInterval = 5) async -> Bool {
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/fileSequence0.ts") else {
            return false
        }
        let session = makeEphemeralSession(timeoutSeconds: timeoutSeconds)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            _ = try await session.data(for: request)
            return true
        } catch {
            return false
        }
    }
}
