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
    static let segmentURL = baseURL.appendingPathComponent("fixtures/segment0.ts")
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
    #EXT-X-ENDLIST
    """
    
    static let mediaSegments: [URL: Data] = [
        segmentURL: Data(repeating: 0xFF, count: 4 * 1024)
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
}


