import Foundation

// swiftlint:disable all

// MARK: - M3U8 Parser Types

/**
 * Params for the parsing operation
 */
public struct M3U8ParserParams {
    var playlist: String
    let playlistType: PlaylistType
    let baseUrl: URL
    
    public init(playlist: String, playlistType: PlaylistType, baseUrl: URL) {
        self.playlist = playlist
        self.playlistType = playlistType
        self.baseUrl = baseUrl
    }
}

/**
 * Result of the parsing operation
 */
public enum M3U8ParserResult: Sendable {
    case master(MasterPlaylist)
    case media(MediaPlaylist)
    case cancelled
}

/**
 * Error types for the parser
 */
public enum M3U8ParserError: LocalizedError {
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let message):
            return "M3U8 parsing failed: \(message)"
        }
    }
}

// swiftlint:enable all
