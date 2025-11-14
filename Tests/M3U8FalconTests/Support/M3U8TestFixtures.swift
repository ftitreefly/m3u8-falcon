//
//  M3U8TestFixtures.swift
//  M3U8FalconTests
//
//  Provides reusable M3U8 playlist fixtures and registers them with MockURLProtocol.
//

import Foundation
@testable import M3U8Falcon

enum M3U8TestFixtures {
    static let baseURL = URL(string: "https://test.local")!
    static let masterPlaylistURL = baseURL.appendingPathComponent("fixtures/master.m3u8")
    static let mediaPlaylistURL = baseURL.appendingPathComponent("fixtures/media.m3u8")
    static let segment0URL = baseURL.appendingPathComponent("fixtures/segment0.ts")
    static let segment1URL = baseURL.appendingPathComponent("fixtures/segment1.ts")
    static let segment2URL = baseURL.appendingPathComponent("fixtures/segment2.ts")
    static let segmentURL = segment0URL
    static let unreachableURL = baseURL.appendingPathComponent("fixtures/unreachable.m3u8")
    
    static let playlistMap: [URL: PlaylistType] = [
        masterPlaylistURL: .master,
        mediaPlaylistURL: .media
    ]
    
    static let masterPlaylist = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-INDEPENDENT-SEGMENTS
    #EXT-X-STREAM-INF:BANDWIDTH=150000,CODECS="avc1.4d401f,mp4a.40.2",RESOLUTION=640x360
    media.m3u8
    """
    
    static let mediaPlaylist = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-TARGETDURATION:10
    #EXTINF:10.0,
    segment0.ts
    #EXTINF:10.0,
    segment1.ts
    #EXTINF:10.0,
    segment2.ts
    #EXT-X-ENDLIST
    """
    
    static let segmentURLs = [segment0URL, segment1URL, segment2URL]
    
    static let mediaSegments: [URL: Data] = [
        segment0URL: Data(repeating: 0xFF, count: 4 * 1024),
        segment1URL: Data(repeating: 0xAA, count: 2 * 1024),
        segment2URL: Data(repeating: 0x55, count: 3 * 1024)
    ]
    
    static func registerAllFixtures() {
        MockURLProtocol.registerSuccess(
            for: masterPlaylistURL,
            headers: ["Content-Type": "application/vnd.apple.mpegurl"],
            data: Data(masterPlaylist.utf8)
        )
        
        MockURLProtocol.registerSuccess(
            for: mediaPlaylistURL,
            headers: ["Content-Type": "application/vnd.apple.mpegurl"],
            data: Data(mediaPlaylist.utf8)
        )
        
        for (url, data) in mediaSegments {
            MockURLProtocol.registerSuccess(
                for: url,
                headers: ["Content-Type": "video/MP2T"],
                data: data
            )
        }
        
        MockURLProtocol.registerFailure(
            for: unreachableURL,
            error: URLError(.cannotFindHost)
        )
    }
    
    static func registerAllFixtures(on networkClient: MockNetworkClient) {
        networkClient.registerSuccess(
            url: masterPlaylistURL,
            data: Data(masterPlaylist.utf8),
            headers: ["Content-Type": "application/vnd.apple.mpegurl"]
        )
        networkClient.registerSuccess(
            url: mediaPlaylistURL,
            data: Data(mediaPlaylist.utf8),
            headers: ["Content-Type": "application/vnd.apple.mpegurl"]
        )
        for (url, data) in mediaSegments {
            networkClient.registerSuccess(
                url: url,
                data: data,
                headers: ["Content-Type": "video/MP2T"]
            )
        }
        networkClient.registerFailure(
            url: unreachableURL,
            error: URLError(.cannotFindHost)
        )
    }
}


