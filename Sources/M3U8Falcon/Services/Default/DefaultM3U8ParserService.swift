//
//  DefaultM3U8ParserService.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Default M3U8 Parser Service

/// Default implementation of the M3U8 parser service
/// 
/// This service is a thin wrapper around `M3U8Parser` that constructs
/// parser parameters and returns a typed parse result. It provides a
/// stateless, thread-safe interface for parsing M3U8 playlists.
/// 
/// ## Features
/// - Stateless design - safe for concurrent use
/// - Supports both master and media playlists
/// - Automatic relative URL resolution using base URL
/// - Comprehensive error reporting via `ParsingError`
/// 
/// ## Usage Example
/// ```swift
/// let parserService = DefaultM3U8ParserService()
/// 
/// // Parse a media playlist
/// let playlistContent = """
/// #EXTM3U
/// #EXTINF:10.0,
/// segment1.ts
/// """
/// let baseURL = URL(string: "https://example.com/")!
/// let result = try parserService.parseContent(playlistContent, baseURL: baseURL, type: .media)
/// 
/// switch result {
/// case .media(let mediaPlaylist):
///     print("Parsed \(mediaPlaylist.tags.mediaSegments.count) segments")
/// case .master(let masterPlaylist):
///     print("Parsed master playlist with \(masterPlaylist.tags.streamTags.count) streams")
/// case .cancelled:
///     print("Parsing was cancelled")
/// }
/// ```
public struct DefaultM3U8ParserService: M3U8ParserServiceProtocol {

    /// Creates a default parser service
    /// 
    /// The parser service is stateless and can be safely reused across
    /// multiple parsing operations.
    public init() {}

    /// Parses M3U8 content and returns a typed result
    /// 
    /// This method creates a new `M3U8Parser` instance, constructs the
    /// parsing parameters, and delegates to the parser to perform the
    /// actual parsing operation.
    /// 
    /// - Parameters:
    ///   - content: Raw M3U8 playlist content (UTF-8 encoded string)
    ///   - baseURL: Base URL used to resolve relative segment URIs in the playlist
    ///   - type: Expected playlist type (`.master`, `.media`, `.subtitles`, `.audio`, or `.video`)
    /// 
    /// - Returns: Parsed `M3U8Parser.ParserResult` containing either a master or media playlist
    /// 
    /// - Throws: 
    ///   - `ParsingError` (aliased as `M3U8Parser.Error`) if the playlist cannot be parsed
    ///   - `ParsingError.malformedPlaylist` if the content format is invalid
    ///   - `ParsingError.missingRequiredTag` if required tags are missing
    ///   - `ParsingError.invalidTag` if tag format is invalid
    public func parseContent(_ content: String, baseURL: URL, type: PlaylistType) throws -> M3U8Parser.ParserResult {
        let parser = M3U8Parser()
        let params = M3U8Parser.Params(playlist: content, playlistType: type, baseUrl: baseURL)
        return try parser.parse(params: params)
    }
}
