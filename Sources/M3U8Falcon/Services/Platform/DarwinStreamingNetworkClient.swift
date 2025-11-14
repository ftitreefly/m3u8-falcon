//
//  DarwinStreamingNetworkClient.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/14.
//

#if canImport(Darwin)
import Foundation

/// Darwin-specific streaming network client using URLSession.bytes
final class DarwinStreamingNetworkClient: StreamingNetworkClientProtocol {
    private let session: URLSession
    
    init(session: URLSession) {
        self.session = session
    }
    
    func fetchAsyncBytes(from url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>) {
        let (asyncBytes, response) = try await session.bytes(from: url)
        
        // Convert AsyncBytes to AsyncThrowingStream<UInt8, Error>
        let stream = AsyncThrowingStream<UInt8, Error> { continuation in
            Task {
                do {
                    for try await byte in asyncBytes {
                        continuation.yield(byte)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        
        return (response, stream)
    }
}

#endif

