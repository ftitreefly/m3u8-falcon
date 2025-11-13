//
//  DefaultM3U8Downloader.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//
import Foundation

// MARK: - Default M3U8 Downloader

/// High-performance M3U8 downloader using Swift 6 features
/// 
/// This downloader wraps a lightweight networking client and provides
/// efficient helpers for fetching playlists and segments with bounded
/// concurrency. It respects the headers and timeouts from `DIConfiguration`.
public struct DefaultM3U8Downloader: M3U8DownloaderProtocol {
    private let commandExecutor: CommandExecutorProtocol
    private let configuration: DIConfiguration
    private let networkClient: NetworkClientProtocol
    
    /// Initializes a new downloader
    /// - Parameters:
    ///   - commandExecutor: Executor for shell tools (e.g., ffmpeg) if needed
    ///   - configuration: DI configuration providing headers, timeouts, etc.
    ///   - networkClient: Optional custom network client. Defaults to `DefaultNetworkClient`.
    public init(commandExecutor: CommandExecutorProtocol, configuration: DIConfiguration, networkClient: NetworkClientProtocol? = nil) {
        self.commandExecutor = commandExecutor
        self.configuration = configuration
        if let client = networkClient {
            self.networkClient = client
        } else {
            self.networkClient = DefaultNetworkClient(configuration: configuration)
        }
    }
    
    /// Downloads textual M3U8 content from the given URL
    /// - Parameter url: M3U8 URL
    /// - Returns: UTF-8 string content (empty if decoding fails)
    /// - Throws: `NetworkError` when request fails or non-200 status received
    public func downloadContent(from url: URL) async throws -> String {
        let data = try await downloadRawData(from: url)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Downloads raw data from a given URL using a reusable URLSession
    /// - Parameter url: Resource URL
    /// - Returns: Raw data
    /// - Throws: `NetworkError` when request fails or non-200 status received
    public func downloadRawData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: configuration.downloadTimeout)
        for (key, value) in configuration.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await networkClient.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(url, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
    
    /// Downloads segments concurrently with controlled concurrency
    /// - Parameters:
    ///   - urls: Segment URLs
    ///   - directory: Destination directory
    ///   - headers: Extra HTTP headers per request
    /// - Throws: `NetworkError` for failed requests; `FileSystemError` for write failures
    public func downloadSegments(at urls: [URL], to directory: URL, headers: [String: String]) async throws {
        // Use TaskGroup for concurrent downloads with controlled concurrency
        let maxConcurrency = min(configuration.maxConcurrentDownloads, urls.count)
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            var activeDownloads = 0
            var urlIndex = 0
            
            // Start initial batch of downloads
            while activeDownloads < maxConcurrency && urlIndex < urls.count {
                let url = urls[urlIndex]
                group.addTask {
                    try await self.downloadSingleSegment(url: url, to: directory, headers: headers)
                }
                activeDownloads += 1
                urlIndex += 1
            }
            
            // Process completed downloads and start new ones
            while activeDownloads > 0 {
                try await group.next()
                activeDownloads -= 1
                
                // Start next download if available
                if urlIndex < urls.count {
                    let url = urls[urlIndex]
                    group.addTask {
                        try await self.downloadSingleSegment(url: url, to: directory, headers: headers)
                    }
                    activeDownloads += 1
                    urlIndex += 1
                }
            }
        }
    }
    
    /// Downloads a single segment and writes to disk (atomic).
    /// - Parameters:
    ///   - url: Segment URL
    ///   - directory: Destination directory
    ///   - headers: Additional headers merged with configuration defaults
    /// - Throws: `NetworkError` for request failures; `FileSystemError` for write failures
    private func downloadSingleSegment(url: URL, to directory: URL, headers: [String: String]) async throws {
        var request = URLRequest(url: url, timeoutInterval: configuration.downloadTimeout)
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add default headers
        for (key, value) in configuration.defaultHeaders where !headers.keys.contains(key) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await networkClient.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError(url, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        let filename = url.lastPathComponent
        let fileURL = directory.appendingPathComponent(filename)
        
        try data.write(to: fileURL, options: .atomic)
    }
}


