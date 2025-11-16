//
//  ParseTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/10.
//

import Foundation
@testable import M3U8Falcon
import Testing

@Suite("Parse Tests")
final class ParseTests {
    
    private var parser: M3U8Parser
    
    init() {
        parser = M3U8Parser()
    }
    
    // MARK: - M3U8Parser Tests
    
    @Test("Parse master playlist")
    func parseMasterPlaylist() throws {
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
            #expect(masterPlaylist.baseUrl == baseUrl)
            #expect(masterPlaylist.tags.versionTag != nil)
            #expect(masterPlaylist.tags.versionTag?.value == 3)
            #expect(masterPlaylist.tags.streamTags.count == 3)
            
            let firstStream = masterPlaylist.tags.streamTags[0]
            #expect(firstStream.text.contains("BANDWIDTH=1280000"))
            #expect(firstStream.text.contains("RESOLUTION=640x360"))
            
        case .media:
            Issue.record("Expected master playlist but got media playlist")
        case .cancelled:
            Issue.record("Parsing was cancelled")
        }
    }
    
    @Test("Parse media playlist")
    func parseMediaPlaylist() throws {
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
            Issue.record("Expected media playlist but got master playlist")
        case .media(let mediaPlaylist):
            #expect(mediaPlaylist.baseUrl == baseUrl)
            #expect(mediaPlaylist.tags.targetDurationTag.value == 10)
            #expect(mediaPlaylist.tags.versionTag != nil)
            #expect(mediaPlaylist.tags.versionTag?.value == 3)
            #expect(mediaPlaylist.tags.mediaSequence != nil)
            #expect(mediaPlaylist.tags.mediaSequence?.value == 0)
            #expect(mediaPlaylist.tags.mediaSegments.count == 3)
            
            let firstSegment = mediaPlaylist.tags.mediaSegments[0]
            #expect(abs(firstSegment.value - 9.009) < 0.001)
            
        case .cancelled:
            Issue.record("Parsing was cancelled")
        }
    }
    
    @Test("Parse empty playlist")
    func parseEmptyPlaylist() throws {
        let emptyContent = ""
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: emptyContent, playlistType: .media, baseUrl: baseUrl)
        
        do {
            _ = try parser.parse(params: params)
            Issue.record("Empty playlist should throw error")
        } catch let parserError as ParsingError {
            #expect(parserError.message.contains("Failed to build"))
        } catch {
            Issue.record("Expected ParsingError, got \(type(of: error))")
        }
    }
    
    @Test("Parse invalid playlist")
    func parseInvalidPlaylist() throws {
        let invalidContent = """
        This is not a valid M3U8 content
        It does not contain proper tags
        """
        
        let baseUrl = URL(string: "https://example.com/")!
        let params = M3U8Parser.Params(playlist: invalidContent, playlistType: .media, baseUrl: baseUrl)
        
        do {
            _ = try parser.parse(params: params)
            Issue.record("Invalid format should throw error")
        } catch let parserError as ParsingError {
            #expect(parserError.message.contains("Failed to build"))
        } catch {
            Issue.record("Expected ParsingError, got \(type(of: error))")
        }
    }
    
    @Test("Parser cancel")
    func parserCancel() throws {
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
            break
        case .master, .media:
            Issue.record("Parsing should be cancelled")
        }
    }
    
    @Test("Parser reset")
    func parserReset() throws {
        // First cancel the parser
        parser.cancel()
        
        // Verify cancelled state
        let cancelledContent = "#EXTM3U\n#EXT-X-VERSION:3"
        let baseUrl = URL(string: "https://example.com/")!
        let cancelledParams = M3U8Parser.Params(playlist: cancelledContent, playlistType: .master, baseUrl: baseUrl)
        
        let cancelledResult = try parser.parse(params: cancelledParams)
        
        switch cancelledResult {
        case .cancelled:
            break
        case .master, .media:
            Issue.record("Parsing should be cancelled")
        }
        
        parser.reset()
        
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
            break
        case .media:
            Issue.record("Expected master playlist")
        case .cancelled:
            Issue.record("Parsing should not be cancelled because it was reset")
        }
    }
    
    @Test("Parse media playlist with key")
    func parseMediaPlaylistWithKey() throws {
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
            #expect(mediaPlaylist.tags.keySegments.count == 1)
            let keySegment = mediaPlaylist.tags.keySegments[0]
            #expect(keySegment.text.contains("METHOD=AES-128"))
            #expect(keySegment.text.contains("URI=\"https://example.com/key.key\""))
        case .master:
            Issue.record("Expected media playlist")
        case .cancelled:
            Issue.record("Parsing was cancelled")
        }
    }
    
    @Test("Parse master playlist with media")
    func parseMasterPlaylistWithMedia() throws {
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
            #expect(masterPlaylist.tags.versionTag != nil)
            #expect(masterPlaylist.tags.versionTag?.value == 4)
            
            #expect(masterPlaylist.tags.mediaTags.count == 2)
            
            let firstMedia = masterPlaylist.tags.mediaTags[0]
            #expect(firstMedia.text.contains("TYPE=AUDIO"))
            #expect(firstMedia.text.contains("GROUP-ID=\"audio\""))
            #expect(firstMedia.text.contains("LANGUAGE=\"en\""))
            
            let secondMedia = masterPlaylist.tags.mediaTags[1]
            #expect(secondMedia.text.contains("TYPE=AUDIO"))
            #expect(secondMedia.text.contains("LANGUAGE=\"es\""))
            
            #expect(masterPlaylist.tags.streamTags.count == 1)
            let streamTag = masterPlaylist.tags.streamTags[0]
            #expect(streamTag.text.contains("BANDWIDTH=1280000"))
            #expect(streamTag.text.contains("RESOLUTION=640x360"))
            
        case .media:
            Issue.record("Expected master playlist")
        case .cancelled:
            Issue.record("Parsing was cancelled")
        }
    }
    
    @Test("Parser performance with large playlist")
    func parserPerformance() throws {
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
        
        let result = try parser.parse(params: params)
        switch result {
        case .media(let mediaPlaylist):
            #expect(mediaPlaylist.tags.mediaSegments.count == 500)
        case .master:
            Issue.record("Expected media playlist")
        case .cancelled:
            Issue.record("Parsing was cancelled")
        }
        parser.reset()
    }
    
    @Test("Different playlist types")
    func differentPlaylistTypes() throws {
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
                #expect(mediaPlaylist.tags.mediaSegments.count == 1)
            case .master:
                Issue.record("For \(playlistType) type, expected media playlist")
            case .cancelled:
                Issue.record("Parsing was cancelled")
            }
            
            parser.reset()
        }
    }
}
