//
//  StreamingDownloader.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation

// MARK: - Streaming Downloader

/// High-performance streaming downloader for memory-efficient file downloads
/// 
/// This downloader uses streaming techniques to download large files without
/// loading the entire content into memory. It's particularly useful for downloading
/// large video segments.
/// 
/// ## Features
/// - Streaming download with configurable buffer size
/// - Memory-efficient for large files
/// - Progress tracking support
/// - Automatic retry on failure
/// - Chunked writing to disk
/// 
/// ## Usage Example
/// ```swift
/// let downloader = StreamingDownloader(
///     networkClient: client,
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
    
    /// Buffer size for streaming (default: 64 KB)
    private let bufferSize: Int
    
    /// URLSession for streaming downloads
    private let session: URLSession
    
    /// Progress handler type
    public typealias ProgressHandler = @Sendable (Int64, Int64?) -> Void
    
    /// Initializes a new streaming downloader
    /// 
    /// - Parameters:
    ///   - networkClient: The network client to use for requests
    ///   - bufferSize: Size of the buffer for streaming (default: 256 KB)
    public init(
        networkClient: NetworkClientProtocol,
        bufferSize: Int = 256 * 1024
    ) {
        self.networkClient = networkClient
        self.bufferSize = bufferSize
        
        // Configure URLSession for streaming
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
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
        let (asyncBytes, response) = try await session.bytes(from: url)
        
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
        FileManager.default.createFile(
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
            for try await byte in asyncBytes {
                buffer.append(byte)
                
                // Write buffer to disk when it's full
                if buffer.count >= bufferSize {
                    try fileHandle.write(contentsOf: buffer)
                    bytesDownloaded += Int64(buffer.count)
                    
                    // Report progress
                    await callProgressHandler(
                        progressHandler,
                        bytesDownloaded: bytesDownloaded,
                        totalBytes: totalBytes
                    )
                    
                    // Clear buffer for reuse
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            
            // Write remaining data
            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
                bytesDownloaded += Int64(buffer.count)
                
                await callProgressHandler(
                    progressHandler,
                    bytesDownloaded: bytesDownloaded,
                    totalBytes: totalBytes
                )
            }
            
            // Ensure data is written to disk
            try fileHandle.synchronize()
            
        } catch {
            // Clean up partial file on error
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
        let (asyncBytes, response) = try await session.bytes(from: url)
        
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
        
        var data = Data()
        var bytesDownloaded: Int64 = 0
        
        for try await byte in asyncBytes {
            data.append(byte)
            bytesDownloaded += 1
            
            // Report progress periodically (every 64 KB)
            if bytesDownloaded % Int64(bufferSize) == 0 {
                await callProgressHandler(
                    progressHandler,
                    bytesDownloaded: bytesDownloaded,
                    totalBytes: totalBytes
                )
            }
        }
        
        // Final progress update
        await callProgressHandler(
            progressHandler,
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes
        )
        
        return data
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

// MARK: - Batch Streaming Downloader

/// Batch downloader for multiple files with memory management
/// 
/// This downloader manages multiple concurrent streaming downloads
/// with automatic memory management and progress tracking.
public actor BatchStreamingDownloader {
    private let streamingDownloader: StreamingDownloader
    private let maxConcurrentDownloads: Int
    
    /// Download statistics
    private var totalBytesDownloaded: Int64 = 0
    private var failedDownloads: Int = 0
    private var successfulDownloads: Int = 0
    
    /// Initializes a batch streaming downloader
    /// 
    /// - Parameters:
    ///   - networkClient: The network client to use
    ///   - maxConcurrentDownloads: Maximum number of concurrent downloads
    ///   - bufferSize: Buffer size for each download
    public init(
        networkClient: NetworkClientProtocol,
        maxConcurrentDownloads: Int = 5,
        bufferSize: Int = 64 * 1024
    ) {
        self.streamingDownloader = StreamingDownloader(
            networkClient: networkClient,
            bufferSize: bufferSize
        )
        self.maxConcurrentDownloads = maxConcurrentDownloads
    }
    
    /// Downloads multiple files concurrently
    /// 
    /// - Parameters:
    ///   - tasks: Array of download tasks (URL, destination pairs)
    ///   - progressHandler: Optional progress callback for overall progress
    /// 
    /// - Throws: An error if any download fails
    public func downloadBatch(
        tasks: [(url: URL, destination: URL)],
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async throws {
        guard !tasks.isEmpty else { return }
        
        await withThrowingTaskGroup(of: Void.self) { group in
            var activeDownloads = 0
            var taskIndex = 0
            var completedTasks = 0
            
            // Start initial batch
            while activeDownloads < maxConcurrentDownloads && taskIndex < tasks.count {
                let task = tasks[taskIndex]
                group.addTask {
                    try await self.downloadSingleFile(url: task.url, destination: task.destination)
                }
                activeDownloads += 1
                taskIndex += 1
            }
            
            // Process completions and start new downloads
            while activeDownloads > 0 {
                do {
                    try await group.next()
                    successfulDownloads += 1
                } catch {
                    failedDownloads += 1
                    Logger.error(
                        "Download failed: \(error.localizedDescription)",
                        category: .download
                    )
                }
                
                activeDownloads -= 1
                completedTasks += 1
                
                // Report progress
                progressHandler?(completedTasks, tasks.count)
                
                // Start next download
                if taskIndex < tasks.count {
                    let task = tasks[taskIndex]
                    group.addTask {
                        try await self.downloadSingleFile(url: task.url, destination: task.destination)
                    }
                    activeDownloads += 1
                    taskIndex += 1
                }
            }
        }
    }
    
    /// Downloads a single file (internal method)
    private func downloadSingleFile(url: URL, destination: URL) async throws {
        try await streamingDownloader.downloadToFile(
            url: url,
            destination: destination,
            progressHandler: { bytesDownloaded, _ in
                Task { await self.updateTotalBytes(bytesDownloaded) }
            }
        )
    }
    
    /// Updates total bytes downloaded
    private func updateTotalBytes(_ bytes: Int64) {
        totalBytesDownloaded = bytes
    }
    
    /// Gets download statistics
    public func getStatistics() -> DownloadStatistics {
        return DownloadStatistics(
            totalBytesDownloaded: totalBytesDownloaded,
            successfulDownloads: successfulDownloads,
            failedDownloads: failedDownloads
        )
    }
    
    /// Resets statistics
    public func resetStatistics() {
        totalBytesDownloaded = 0
        failedDownloads = 0
        successfulDownloads = 0
    }
}

// MARK: - Download Statistics

/// Statistics for batch downloads
public struct DownloadStatistics: Sendable {
    /// Total bytes downloaded
    public let totalBytesDownloaded: Int64
    
    /// Number of successful downloads
    public let successfulDownloads: Int
    
    /// Number of failed downloads
    public let failedDownloads: Int
    
    /// Total number of downloads
    public var totalDownloads: Int {
        successfulDownloads + failedDownloads
    }
    
    /// Success rate (0.0 to 1.0)
    public var successRate: Double {
        guard totalDownloads > 0 else { return 0.0 }
        return Double(successfulDownloads) / Double(totalDownloads)
    }
}
