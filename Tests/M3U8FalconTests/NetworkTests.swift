//
//  NetworkTests.swift
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

final class NetworkTests: XCTestCase {
    
    private var session: URLSession!
    private var parser: M3U8Parser!
    
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        M3U8TestFixtures.registerAllFixtures()
        session = URLSession(configuration: MockURLProtocol.makeEphemeralConfiguration(timeoutSeconds: 5))
        parser = M3U8Parser()
    }
    
    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        parser = nil
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - Basic Network Tests
    
    func testBasicM3U8Download() async throws {
        let url = M3U8TestFixtures.masterPlaylistURL
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            XCTFail("Response is not HTTP")
            return
        }
        
        XCTAssertEqual(httpResponse.statusCode, 200)
        
        guard case .master(let playlist) = try parsePlaylist(
            data: data,
            playlistType: .master,
            url: url
        ) else {
            XCTFail("Expected master playlist")
            return
        }
        
        XCTAssertEqual(playlist.tags.streamTags.count, 1)
    }
    
    func testMultipleM3U8URLs() async throws {
        for (url, type) in M3U8TestFixtures.playlistMap {
            let (data, response) = try await session.data(from: url)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            let result = try parsePlaylist(data: data, playlistType: type, url: url)
            
            switch (result, type) {
            case (.master(let playlist), .master):
                XCTAssertGreaterThan(playlist.tags.streamTags.count, 0)
            case (.media(let playlist), .media):
                XCTAssertGreaterThan(playlist.tags.mediaSegments.count, 0)
            default:
                XCTFail("Unexpected playlist type for \(url.absoluteString)")
            }
        }
    }
    
    // MARK: - M3U8 Content Analysis
    
    func testM3U8ContentAnalysis() async throws {
        let (data, _) = try await session.data(from: M3U8TestFixtures.masterPlaylistURL)
        guard case .master(let playlist) = try parsePlaylist(
            data: data,
            playlistType: .master,
            url: M3U8TestFixtures.masterPlaylistURL
        ) else {
            XCTFail("Expected master playlist")
            return
        }
        
        XCTAssertEqual(playlist.tags.streamTags.count, 1)
        XCTAssertEqual(playlist.tags.streamTags.first?.bandwidth, 150_000)
        XCTAssertEqual(playlist.tags.streamTags.first?.resolution, "640x360")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidURL() async throws {
        do {
            _ = try await session.data(from: M3U8TestFixtures.unreachableURL)
            XCTFail("Expected failure for unreachable URL")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testDownloadPerformance() async throws {
        let start = Date()
        let (data, response) = try await session.data(from: M3U8TestFixtures.segmentURL)
        let elapsed = Date().timeIntervalSince(start)
        
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let expectedSize = M3U8TestFixtures.mediaSegments[M3U8TestFixtures.segmentURL]?.count ?? 0
        XCTAssertEqual(data.count, expectedSize)
        XCTAssertLessThan(elapsed, 0.1, "Fixture download should be near-instant")
    }
    
    // MARK: - Integration with M3U8Falcon
    
    func testM3U8FalconIntegration() async throws {
        let url = M3U8TestFixtures.mediaPlaylistURL
        let (data, _) = try await session.data(from: url)
        
        guard case .media(let playlist) = try parsePlaylist(
            data: data,
            playlistType: .media,
            url: url
        ) else {
            XCTFail("Expected media playlist")
            return
        }
        
        XCTAssertEqual(playlist.tags.mediaSegments.count, 3)
    }
    
    // MARK: - Helpers
    
    private func parsePlaylist(
        data: Data,
        playlistType: PlaylistType,
        url: URL
    ) throws -> M3U8Parser.ParserResult {
        let content = try XCTUnwrap(String(data: data, encoding: .utf8))
        let params = M3U8Parser.Params(
            playlist: content,
            playlistType: playlistType,
            baseUrl: url.deletingLastPathComponent()
        )
        return try parser.parse(params: params)
    }
}
