//
//  Playlist.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//
//  Some code in this file is referenced or adapted from go-swifty-m3u8 (https://github.com/gal-orlanczyk/go-swifty-m3u8)
//  Copyright (c) Gal Orlanczyk
//  Licensed under the MIT License.
//
//  The MIT License (MIT)
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// swiftlint:disable all

/* ***********************************************************/
// MARK: - Playlist
/* ***********************************************************/

/// `Playlist` protocol represents a playlist with a list of tags.
/// A playlist can be master or media playlist.
public protocol Playlist: Sendable {
    /// The base url of the playlist.
    var baseUrl: URL? { get }
    /// dictionary of extra tags mapping to: [tag (EXT...): array of same type of tags]
    var extraTags: [String: [any Tag]] { get }
}

/* ***********************************************************/
// MARK: - PlaylistType
/* ***********************************************************/

/// `PlaylistType` represents the type of the playlist.
public enum PlaylistType: Sendable {
    case master, media
            case video, audio, subtitles // Keep support for old types

    /// The default handled tags for each playlist type, this is used a default by the parser.
    public var handledTagTypes: [any Tag.Type] {
        switch self {
        case .master:
            return [
                EXTM3U.self,
                EXT_X_VERSION.self,
                EXT_X_STREAM_INF.self,
                EXT_X_MEDIA.self,
            ]
        case .media, .video, .audio, .subtitles:
            return [
                EXTM3U.self,
                EXT_X_VERSION.self,
                EXT_X_TARGETDURATION.self,
                EXT_X_MEDIA_SEQUENCE.self,
                EXT_X_PLAYLIST_TYPE.self,
                EXT_X_ALLOW_CACHE.self,
                EXTINF.self,
                EXT_X_KEY.self,
                EXT_X_ENDLIST.self,
            ]
        }
    }
}

// swiftlint:enable all
