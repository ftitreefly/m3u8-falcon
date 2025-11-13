//
//  Array+Extensions.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

/// Array extensions for URL processing in M3U8 operations
/// 
/// This extension provides utility methods for processing arrays of URLs,
/// specifically designed for M3U8 segment handling and concurrent processing.
extension Array where Element == URL {
    /// Efficiently filters and sorts segment URLs using Swift 6 features
    /// 
    /// This method filters an array of URLs to include only video segment files
    /// (`.ts` or `.m4s` files) and sorts them in natural order for proper
    /// video playback sequence.
    /// 
    /// - Returns: A filtered and sorted array of segment URLs
    /// 
    /// ## Usage Example
    /// ```swift
    /// let urls = [
    ///     URL(string: "https://example.com/segment3.ts")!,
    ///     URL(string: "https://example.com/segment1.ts")!,
    ///     URL(string: "https://example.com/playlist.m3u8")!,
    ///     URL(string: "https://example.com/segment2.ts")!,
    ///     URL(string: "https://example.com/segment10.ts")!
    /// ]
    /// 
    /// let sortedSegments = urls.optimizedSegmentSort()
    /// // Result: [segment1.ts, segment2.ts, segment3.ts, segment10.ts]
    /// // Note: playlist.m3u8 is filtered out
    /// ```
    func optimizedSegmentSort() -> [URL] {
        return self
            .filter { url in
                // Use Swift 6's improved string processing
                let filename = url.lastPathComponent
                return filename.hasSuffix(".ts") || filename.hasSuffix(".m4s")
            }
            .sorted { url1, url2 in
                // Natural ordering for segment files
                url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
            }
    }
    
    /// Batches URLs for concurrent processing
    /// 
    /// This method divides an array of URLs into smaller batches for efficient
    /// concurrent processing, useful for controlling the number of simultaneous
    /// downloads or operations.
    /// 
    /// - Parameter size: The maximum number of URLs per batch
    /// 
    /// - Returns: An array of URL batches, where each batch contains at most `size` URLs
    /// 
    /// ## Usage Example
    /// ```swift
    /// let urls = [
    ///     URL(string: "https://example.com/segment1.ts")!,
    ///     URL(string: "https://example.com/segment2.ts")!,
    ///     URL(string: "https://example.com/segment3.ts")!,
    ///     URL(string: "https://example.com/segment4.ts")!,
    ///     URL(string: "https://example.com/segment5.ts")!
    /// ]
    /// 
    /// let batches = urls.batched(size: 2)
    /// // Result: [
    /// //   [segment1.ts, segment2.ts],
    /// //   [segment3.ts, segment4.ts],
    /// //   [segment5.ts]
    /// // ]
    /// 
    /// // Process batches concurrently
    /// for batch in batches {
    ///     Task {
    ///         await downloadSegments(batch)
    ///     }
    /// }
    /// ```
    func batched(size: Int) -> [[URL]] {
        var batches: [[URL]] = []
        batches.reserveCapacity((count + size - 1) / size)
        
        // swiftlint:disable:next identifier_name
        for i in stride(from: 0, to: count, by: size) {
            let endIndex = Swift.min(i + size, count)
            batches.append(Array(self[i..<endIndex]))
        }
        
        return batches
    }
}
