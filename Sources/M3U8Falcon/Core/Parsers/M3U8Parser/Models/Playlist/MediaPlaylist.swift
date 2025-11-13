//
//  MediaPlaylist.swift
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

/// `MediaPlaylist` represents a media playlist with all the media playlist tags.
public struct MediaPlaylist: Playlist {
    /// The base url of the playlist.
    public let baseUrl: URL?
    /// the media playlist tags
    public let tags: MediaPlaylistTags
    public let extraTags: [String: [any Tag]]
}

/// `MediaPlaylistTags` contains media playlists tags
public struct MediaPlaylistTags: Sendable {
    public let targetDurationTag: EXT_X_TARGETDURATION
    public let allowCacheTag: EXT_X_ALLOW_CACHE?
    public let playlistTypeTag: EXT_X_PLAYLIST_TYPE?
    public let versionTag: EXT_X_VERSION?
    public let mediaSequence: EXT_X_MEDIA_SEQUENCE?
    public let mediaSegments: [EXTINF]
    public let keySegments: [EXT_X_KEY]
    public let endListTag: EXT_X_ENDLIST?
}

/// `MediaPlaylistTagsBuilder` used to build `MediaPlaylistTags` object.
/// Aggregates the results when parsing and building at the end.
class MediaPlaylistTagsBuilder {
    var targetDurationTag: EXT_X_TARGETDURATION?
    var allowCacheTag: EXT_X_ALLOW_CACHE?
    var playlistTypeTag: EXT_X_PLAYLIST_TYPE?
    var versionTag: EXT_X_VERSION?
    var mediaSequence: EXT_X_MEDIA_SEQUENCE?
    var mediaSegments = [EXTINF]()
    var keySegments = [EXT_X_KEY]()
    var endListTag: EXT_X_ENDLIST?

    func build() -> MediaPlaylistTags? {
        guard let targetDurationTag = self.targetDurationTag else { return nil }
        return MediaPlaylistTags(targetDurationTag: targetDurationTag,
                          allowCacheTag: self.allowCacheTag,
                          playlistTypeTag: self.playlistTypeTag,
                          versionTag: self.versionTag,
                          mediaSequence: self.mediaSequence,
                          mediaSegments: self.mediaSegments,
                          keySegments: self.keySegments,
                          endListTag: self.endListTag)
    }
}

// swiftlint:enable all
