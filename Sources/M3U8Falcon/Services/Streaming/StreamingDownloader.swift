//
//  StreamingDownloader.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Streaming Downloader

/// High-performance streaming downloader for memory-efficient file downloads
/// 
/// This downloader uses streaming techniques to download large files without
/// loading the entire content into memory. It's particularly useful for downloading
/// large video segments. Platform-specific streaming is handled by StreamingNetworkClientProtocol.
/// 
/// ## Features
/// - Platform-abstracted streaming download
/// - Configurable buffer size
/// - Memory-efficient for large files
/// - Progress tracking support
/// - Chunked writing to disk
/// 
/// ## Usage Example
/// ```swift
/// let downloader = StreamingDownloader(
///     networkClient: client,
///     streamingClient: streamingClient,
///     bufferSize: 256 * 1024  // 256 KB buffer
/// )
/// 
/// try await downloader.downloadToFile(
///     url: videoURL,
///     destination: outputFile,
///     progressHandler: { bytesDownloaded, totalBytes in
///         print("Progress: \(bytesDownloaded)/\(totalBytes)")
///     }
/// )
/// ```
public actor StreamingDownloader {
    /// The network client for making requests
    private let networkClient: NetworkClientProtocol
    
    /// The streaming network client for byte stream downloads
    private let streamingClient: StreamingNetworkClientProtocol
    
    /// Buffer size for streaming (default: 256 KB)
    private let bufferSize: Int
    
    /// Progress handler type
    public typealias ProgressHandler = @Sendable (Int64, Int64?) -> Void
    
    /// Initializes a new streaming downloader
    /// 
    /// - Parameters:
    ///   - networkClient: The network client to use for requests
    ///   - streamingClient: Platform-specific streaming client (injected via DI)
    ///   - bufferSize: Size of the buffer for streaming (default: 256 KB)
    public init(
        networkClient: NetworkClientProtocol,
        streamingClient: StreamingNetworkClientProtocol,
        bufferSize: Int = 256 * 1024
    ) {
        self.networkClient = networkClient
        self.streamingClient = streamingClient
        self.bufferSize = bufferSize
    }
    
    /// Downloads a file to disk using streaming
    /// 
    /// This method downloads a file in chunks, writing directly to disk
    /// without loading the entire file into memory.
    /// 
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - destination: The destination file URL
    ///   - progressHandler: Optional progress callback
    /// 
    /// - Throws: 
    ///   - `NetworkError` if the download fails
    ///   - `FileSystemError` if file operations fail
    public func downloadToFile(
        url: URL,
        destination: URL,
        progressHandler: ProgressHandler? = nil
    ) async throws {
        // Validate response and get content length
        let (byteStream, response) = try await fetchAsyncBytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(
                url,
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        
        let totalBytes = httpResponse.expectedContentLength > 0 
            ? httpResponse.expectedContentLength 
            : nil
        
        // Create destination file
        _ = FileManager.default.createFile(
            atPath: destination.path,
            contents: nil,
            attributes: [.posixPermissions: 0o644]
        )
        
        guard let fileHandle = FileHandle(forWritingAtPath: destination.path) else {
            throw FileSystemError.failedToCreateFile(destination.path)
        }
        
        defer {
            try? fileHandle.close()
        }
        
        // Stream download with buffering
        var bytesDownloaded: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(bufferSize)
        
        do {
            for try await byte in byteStream {
                buffer.append(byte)
                
                if buffer.count >= bufferSize {
                    try fileHandle.write(contentsOf: buffer)
                    bytesDownloaded += Int64(buffer.count)
                    
                    await callProgressHandler(
                        progressHandler,
                        bytesDownloaded: bytesDownloaded,
                        totalBytes: totalBytes
                    )
                    
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
                bytesDownloaded += Int64(buffer.count)
                
                await callProgressHandler(
                    progressHandler,
                    bytesDownloaded: bytesDownloaded,
                    totalBytes: totalBytes
                )
            }
            
            try fileHandle.synchronize()
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
    
    /// Downloads a file to memory (for small files)
    /// 
    /// This method is suitable for small files that can fit in memory.
    /// For large files, use `downloadToFile` instead.
    /// 
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - progressHandler: Optional progress callback
    /// 
    /// - Returns: The downloaded data
    /// 
    /// - Throws: `NetworkError` if the download fails
    public func downloadToMemory(
        url: URL,
        progressHandler: ProgressHandler? = nil
    ) async throws -> Data {
        let (byteStream, response) = try await fetchAsyncBytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(
                url,
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        
        let totalBytes = httpResponse.expectedContentLength > 0 
            ? httpResponse.expectedContentLength 
            : nil
        
        var resultData = Data()
        var bytesDownloaded: Int64 = 0
        
        for try await byte in byteStream {
            resultData.append(byte)
            bytesDownloaded += 1
            
            if bytesDownloaded % Int64(bufferSize) == 0 {
                await callProgressHandler(
                    progressHandler,
                    bytesDownloaded: bytesDownloaded,
                    totalBytes: totalBytes
                )
            }
        }
        
        await callProgressHandler(
            progressHandler,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes
        )
        
        return resultData
    }
    
    /// Calls the progress handler safely
    private func callProgressHandler(
        _ handler: ProgressHandler?,
        bytesDownloaded: Int64,
        totalBytes: Int64?
    ) async {
        guard let handler = handler else { return }
        handler(bytesDownloaded, totalBytes)
    }
}

// MARK: - Async Byte Fetching Helpers

private extension StreamingDownloader {
    func fetchAsyncBytes(from url: URL) async throws -> (AsyncThrowingStream<UInt8, Error>, URLResponse) {
        let (response, stream) = try await streamingClient.fetchAsyncBytes(from: url)
        return (stream, response)
    }
}
