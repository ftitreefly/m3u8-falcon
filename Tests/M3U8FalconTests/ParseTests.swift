//
//  ParseTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/10.
//

import Foundation
import XCTest

@testable import M3U8Falcon

final class ParseTests: XCTestCase {
    
    var parser: M3U8Parser!
    
    override func setUpWithError() throws {
        parser = M3U8Parser()
    }
    
    override func tearDownWithError() throws {
        parser = nil
    }
    
    // MARK: - M3U8Parser Tests
    
    /// Test parsing Master Playlist
    func testParseMasterPlaylist() throws {
        let masterPlaylistContent = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-STREAM-INF:BANDWIDTH=1280000,AVERAGE-BANDWIDTH=1000000,CODECS="avc1.42c00d,mp4a.40.2",RESOLUTION=640x360,FRAME-RATE=23.976
        gear1/prog_index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2560000,AVERAGE-BANDWIDTH=2000000,CODECS="avc1.42c015,mp4a.40.2",RESOLUTION=960x540,FRAME-RATE=23.976
        gear2/prog_index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=7680000,AVERAGE-BANDWIDTH=6000000,CODECS="avc1.42c01e,mp4a.40.2",RESOLUTION=1280x720,FRAME-RATE=23.976
        gear3/prog_index.m3u8
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: masterPlaylistContent, playlistType: .master, baseUrl: baseUrl)
        
        let result = try parser.parse(params: params)
        
        switch result {
        case .master(let masterPlaylist):
            XCTAssertEqual(masterPlaylist.baseUrl, baseUrl)
            XCTAssertNotNil(masterPlaylist.tags.versionTag)
            XCTAssertEqual(masterPlaylist.tags.versionTag?.value, 3)
            XCTAssertEqual(masterPlaylist.tags.streamTags.count, 3)
            
            // Verify first stream tag
            let firstStream = masterPlaylist.tags.streamTags[0]
            XCTAssertTrue(firstStream.text.contains("BANDWIDTH=1280000"))
            XCTAssertTrue(firstStream.text.contains("RESOLUTION=640x360"))
            
        case .media:
            XCTFail("Expected master playlist but got media playlist")
        case .cancelled:
            XCTFail("Parsing was cancelled")
        }
    }
    
    /// Test parsing Media Playlist
    func testParseMediaPlaylist() throws {
        let mediaPlaylistContent = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXTINF:9.009,
        fileSequence0.ts
        #EXTINF:9.009,
        fileSequence1.ts
        #EXTINF:9.009,
        fileSequence2.ts
        #EXT-X-ENDLIST
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: mediaPlaylistContent, playlistType: .media, baseUrl: baseUrl)
        
        let result = try parser.parse(params: params)
        
        switch result {
        case .master:
            XCTFail("Expected media playlist but got master playlist")
        case .media(let mediaPlaylist):
            XCTAssertEqual(mediaPlaylist.baseUrl, baseUrl)
            XCTAssertNotNil(mediaPlaylist.tags.targetDurationTag)
            XCTAssertEqual(mediaPlaylist.tags.targetDurationTag.value, 10)
            XCTAssertNotNil(mediaPlaylist.tags.versionTag)
            XCTAssertEqual(mediaPlaylist.tags.versionTag?.value, 3)
            XCTAssertNotNil(mediaPlaylist.tags.mediaSequence)
            XCTAssertEqual(mediaPlaylist.tags.mediaSequence?.value, 0)
            XCTAssertEqual(mediaPlaylist.tags.mediaSegments.count, 3)
            
            // Verify first segment
            let firstSegment = mediaPlaylist.tags.mediaSegments[0]
            XCTAssertEqual(firstSegment.value, 9.009, accuracy: 0.001)
            
        case .cancelled:
            XCTFail("Parsing was cancelled")
        }
    }
    
    /// Test parsing empty playlist
    func testParseEmptyPlaylist() throws {
        let emptyContent = ""
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: emptyContent, playlistType: .media, baseUrl: baseUrl)
        
        // Empty playlist should throw error
        XCTAssertThrowsError(try parser.parse(params: params)) { error in
            if let parserError = error as? ParsingError {
                XCTAssertTrue(parserError.message.contains("Failed to build"))
            }
        }
    }
    
    /// Test parsing invalid format playlist
    func testParseInvalidPlaylist() throws {
        let invalidContent = """
        This is not a valid M3U8 content
        It does not contain proper tags
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: invalidContent, playlistType: .media, baseUrl: baseUrl)
        
        // Invalid format should throw error or return build failure
        XCTAssertThrowsError(try parser.parse(params: params)) { error in
            if let parserError = error as? ParsingError {
                XCTAssertTrue(parserError.message.contains("Failed to build"))
            }
        }
    }
    
    /// Test cancel functionality
    func testParserCancel() throws {
        let longPlaylistContent = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        """ + String(repeating: "#EXTINF:9.009,\nfileSequence.ts\n", count: 1000) + "#EXT-X-ENDLIST"
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: longPlaylistContent, playlistType: .media, baseUrl: baseUrl)
        
        // Cancel parsing immediately
        parser.cancel()
        
        let result = try parser.parse(params: params)
        
        switch result {
        case .cancelled:
            // Expected result
            break
        case .master, .media:
            XCTFail("Parsing should be cancelled")
        }
    }
    
    /// Test reset functionality
    func testParserReset() throws {
        // First cancel the parser
        parser.cancel()
        
        // Verify cancelled state
        let cancelledContent = "#EXTM3U\n#EXT-X-VERSION:3"
        let baseUrl = URL(string: "https://example.com/")!
        let cancelledParams = M3U8Parser.Params(playlist: cancelledContent, playlistType: .master, baseUrl: baseUrl)
        
        let cancelledResult = try parser.parse(params: cancelledParams)
        
        // Verify parsing was cancelled
        switch cancelledResult {
        case .cancelled:
            // Expected result
            break
        case .master, .media:
            XCTFail("Parsing should be cancelled")
        }
        
        // Reset the parser
        parser.reset()
        
        // Now parsing should work normally
        let validContent = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-STREAM-INF:BANDWIDTH=1280000
        gear1/prog_index.m3u8
        """
        let validParams = M3U8Parser.Params(playlist: validContent, playlistType: .master, baseUrl: baseUrl)
        
        let result = try parser.parse(params: validParams)
        
        switch result {
        case .master:
            // Expected result - parsing successful
            break
        case .media:
            XCTFail("Expected master playlist")
        case .cancelled:
            XCTFail("Parsing should not be cancelled because it was reset")
        }
    }
    
    /// Test media playlist with encryption key
    func testParseMediaPlaylistWithKey() throws {
        let mediaPlaylistWithKey = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key.key",IV=0x99b74007b6254e4bd1c6e03631cad15b
        #EXTINF:9.009,
        fileSequence0.ts
        #EXTINF:9.009,
        fileSequence1.ts
        #EXT-X-ENDLIST
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: mediaPlaylistWithKey, playlistType: .media, baseUrl: baseUrl)
        
        let result = try parser.parse(params: params)
        
        switch result {
        case .media(let mediaPlaylist):
            XCTAssertEqual(mediaPlaylist.tags.keySegments.count, 1)
            let keySegment = mediaPlaylist.tags.keySegments[0]
            XCTAssertTrue(keySegment.text.contains("METHOD=AES-128"))
            XCTAssertTrue(keySegment.text.contains("URI=\"https://example.com/key.key\""))
        case .master:
            XCTFail("Expected media playlist")
        case .cancelled:
            XCTFail("Parsing was cancelled")
        }
    }
    
    /// Test master playlist with multimedia tags
    func testParseMasterPlaylistWithMedia() throws {
        let masterWithMedia = """
        #EXTM3U
        #EXT-X-VERSION:4
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",DEFAULT=YES,AUTOSELECT=YES,LANGUAGE="en",URI="audio/prog_index.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",DEFAULT=NO,AUTOSELECT=YES,LANGUAGE="es",URI="audio_es/prog_index.m3u8"
        #EXT-X-STREAM-INF:BANDWIDTH=1280000,CODECS="avc1.42c00d,mp4a.40.2",RESOLUTION=640x360,AUDIO="audio"
        video/prog_index.m3u8
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: masterWithMedia, playlistType: .master, baseUrl: baseUrl)
        
        let result = try parser.parse(params: params)
        
        switch result {
        case .master(let masterPlaylist):
            // Verify version tag
            XCTAssertNotNil(masterPlaylist.tags.versionTag)
            XCTAssertEqual(masterPlaylist.tags.versionTag?.value, 4)
            
            // Verify media tag parsing
            XCTAssertEqual(masterPlaylist.tags.mediaTags.count, 2)
            
            // Verify first audio media tag
            let firstMedia = masterPlaylist.tags.mediaTags[0]
            XCTAssertTrue(firstMedia.text.contains("TYPE=AUDIO"))
            XCTAssertTrue(firstMedia.text.contains("GROUP-ID=\"audio\""))
            XCTAssertTrue(firstMedia.text.contains("LANGUAGE=\"en\""))
            
            // Verify second audio media tag
            let secondMedia = masterPlaylist.tags.mediaTags[1]
            XCTAssertTrue(secondMedia.text.contains("TYPE=AUDIO"))
            XCTAssertTrue(secondMedia.text.contains("LANGUAGE=\"es\""))
            
            // Verify stream tag parsing (should now parse correctly because it includes RESOLUTION)
            XCTAssertEqual(masterPlaylist.tags.streamTags.count, 1)
            let streamTag = masterPlaylist.tags.streamTags[0]
            XCTAssertTrue(streamTag.text.contains("BANDWIDTH=1280000"))
            XCTAssertTrue(streamTag.text.contains("RESOLUTION=640x360"))
            
        case .media:
            XCTFail("Expected master playlist")
        case .cancelled:
            XCTFail("Parsing was cancelled")
        }
    }
    
    /// Test parser performance
    func testParserPerformance() throws {
        // Create a media playlist with many segments
        let segmentsPart = String(repeating: "#EXTINF:9.009,\nfileSequence.ts\n", count: 500)
        let largeMediaPlaylist = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        \(segmentsPart)#EXT-X-ENDLIST
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: largeMediaPlaylist, playlistType: .media, baseUrl: baseUrl)
        
        // Performance test
        measure {
            do {
                let result = try parser.parse(params: params)
                switch result {
                case .media(let mediaPlaylist):
                    // Verify parsing result is correct
                    XCTAssertEqual(mediaPlaylist.tags.mediaSegments.count, 500)
                case .master:
                    XCTFail("Expected media playlist")
                case .cancelled:
                    XCTFail("Parsing was cancelled")
                }
                // Reset parser state after each test
                parser.reset()
            } catch {
                XCTFail("Parsing failed: \(error)")
            }
        }
    }
    
    /// Test support for different PlaylistTypes
    func testDifferentPlaylistTypes() throws {
        let mediaContent = """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXTINF:9.009,
        test.ts
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let playlistTypes: [PlaylistType] = [.media, .video, .audio, .subtitles]
        
        for playlistType in playlistTypes {
            let params = M3U8Parser.Params(playlist: mediaContent, playlistType: playlistType, baseUrl: baseUrl)
            
            let result = try parser.parse(params: params)
            
            switch result {
            case .media(let mediaPlaylist):
                XCTAssertEqual(mediaPlaylist.tags.mediaSegments.count, 1)
                // \(playlistType) type parsing successful
            case .master:
                XCTFail("For \(playlistType) type, expected media playlist")
            case .cancelled:
                XCTFail("Parsing was cancelled")
            }
            
            parser.reset()
        }
    }
}
