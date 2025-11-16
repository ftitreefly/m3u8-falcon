//
//  MockStreamingClient.swift
//  M3U8FalconTests
//
//  Mock streaming client for testing
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon

/// Mock streaming client for testing
final class MockStreamingClient: StreamingNetworkClientProtocol {
    func fetchAsyncBytes(from url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>) {
        // Parse the expected size from the URL if available (e.g., /bytes/512)
        let urlString = url.absoluteString
        var size = 1024 // default size
        
        // Extract size from URL path like /bytes/512
        if let bytesRange = urlString.range(of: "/bytes/") {
            let substring = urlString[bytesRange.upperBound...]
            let endIndex = substring.firstIndex(where: { !$0.isNumber }) ?? urlString.endIndex
            let sizeString = String(urlString[bytesRange.upperBound..<endIndex])
            size = Int(sizeString) ?? 1024
        }
        
        // Create a mock response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Length": "\(size)"]
        )!
        
        // Create a mock byte stream
        let capturedSize = size // Capture size to avoid concurrency issues
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                // Generate mock bytes
                for index in 0..<capturedSize {
                    continuation.yield(UInt8(index % 256))
                }
                continuation.finish()
            }
        }
        
        return (response, stream)
    }
}

