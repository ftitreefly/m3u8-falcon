//
//  MasterPlaylist.swift
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

/// `MasterPlaylist` represents a master playlist with all the master playlist tags.
public struct MasterPlaylist: Playlist {
    /// The base url of the playlist.
    public let baseUrl: URL?
    public let tags: MasterPlaylistTags
    public let extraTags: [String: [any Tag]]
}

/// `MasterPlaylistTags` objects represents tags used by the master playlist
public struct MasterPlaylistTags: Sendable {
    public let versionTag: EXT_X_VERSION?
    public let mediaTags: [EXT_X_MEDIA]
    public let streamTags: [EXT_X_STREAM_INF]
}

/// `MasterPlaylistTagsBuilder` used to build `MasterPlaylistTags` object.
/// Aggregates the results when parsing and building at the end.
class MasterPlaylistTagsBuilder {
    var versionTag: EXT_X_VERSION?
    var mediaTags = [EXT_X_MEDIA]()
    var streamTags = [EXT_X_STREAM_INF]()

    func build() -> MasterPlaylistTags? {
        return MasterPlaylistTags(versionTag: self.versionTag, mediaTags: self.mediaTags, streamTags: self.streamTags)
    }
}
