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
/// parser parameters and returns a typed parse result.
public struct DefaultM3U8ParserService: M3U8ParserServiceProtocol {

    /// Creates a default parser service
    public init() {}

    /// Parses M3U8 content and returns a typed result
    /// 
    /// - Parameters:
    ///   - content: Raw M3U8 playlist content (UTF-8)
    ///   - baseURL: Base URL used to resolve relative segment URIs
    ///   - type: Expected playlist type (master/media/subtitles/audio/video)
    /// - Returns: Parsed `M3U8Parser.ParserResult`
    /// - Throws: `M3U8Parser.Error` on parse failure
    /// 
    /// ## Usage
    /// ```swift
    /// let result = try parserService.parseContent(playlistText, baseURL: baseURL, type: .media)
    /// ```
    public func parseContent(_ content: String, baseURL: URL, type: PlaylistType) throws -> M3U8Parser.ParserResult {
        let parser = M3U8Parser()
        let params = M3U8Parser.Params(playlist: content, playlistType: type, baseUrl: baseURL)
        return try parser.parse(params: params)
    }
} 
