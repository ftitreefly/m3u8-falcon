//
//  String+Extensions.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import CryptoKit
import Foundation

/// String extensions for M3U8 utility operations
/// 
/// This extension provides utility methods for string processing in the context
/// of M3U8 file handling, including segment filename parsing and content generation.
extension String {
    /// Extracts the segment number from a segment filename
    /// 
    /// This method parses segment filenames (e.g., "segment001.ts", "fileSequence5.ts")
    /// and extracts the numeric segment number for sorting and processing purposes.
    /// 
    /// - Returns: The segment number as an integer, or `nil` if no number is found
    /// 
    /// ## Usage Example
    /// ```swift
    /// let filename1 = "segment001.ts"
    /// let filename2 = "fileSequence5.ts"
    /// let filename3 = "video.mp4"
    /// 
    /// print(filename1.segmentNumber) // Optional(1)
    /// print(filename2.segmentNumber) // Optional(5)
    /// print(filename3.segmentNumber) // nil
    /// ```
    var segmentNumber: Int? {
        // Use traditional regex for compatibility
        let pattern = #"(\d+)\.ts$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: self, options: [], range: NSRange(location: 0, length: count)),
           let range = Range(match.range(at: 1), in: self) {
            return Int(String(self[range]))
        }
        return nil
    }
    
    /// Builds optimized M3U8 content from an array of URLs
    /// 
    /// This method efficiently constructs M3U8 playlist content from a list of URLs,
    /// using pre-allocated string capacity for better performance when dealing with
    /// large numbers of segments.
    /// 
    /// - Parameter urls: Array of URLs to include in the M3U8 content
    /// 
    /// - Returns: A string containing the M3U8 playlist content with one URL per line
    /// 
    /// ## Usage Example
    /// ```swift
    /// let segmentURLs = [
    ///     URL(string: "https://example.com/segment1.ts")!,
    ///     URL(string: "https://example.com/segment2.ts")!,
    ///     URL(string: "https://example.com/segment3.ts")!
    /// ]
    /// 
    /// let m3u8Content = String.buildOptimizedM3U8Content(urls: segmentURLs)
    /// print(m3u8Content)
    /// // Output:
    /// // https://example.com/segment1.ts
    /// // https://example.com/segment2.ts
    /// // https://example.com/segment3.ts
    /// ```
    static func buildOptimizedM3U8Content(urls: [URL]) -> String {
        let estimatedCapacity = urls.count * 50 // Rough estimate
        var content = String()
        content.reserveCapacity(estimatedCapacity)
        
        for url in urls {
            content += url.absoluteString + "\n"
        }
        
        return content
    }
}
