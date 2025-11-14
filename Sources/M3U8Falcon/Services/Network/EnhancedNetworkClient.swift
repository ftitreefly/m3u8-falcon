//
//  EnhancedNetworkClient.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Enhanced Network Client

/// High-performance network client with retry logic and connection pooling
/// 
/// This client provides enhanced networking capabilities including:
/// - Automatic retry with configurable strategies
/// - Connection pooling and reuse
/// - Request/response metrics collection
/// - Proper HTTP status code handling
/// - Comprehensive error handling
/// 
/// ## Features
/// - Exponential backoff retry
/// - Connection pool management
/// - Performance monitoring
/// - Thread-safe operations
/// 
/// ## Usage Example
/// ```swift
/// let client = EnhancedNetworkClient(
///     configuration: .performanceOptimized(),
///     retryStrategy: ExponentialBackoffRetryStrategy(),
///     monitor: PerformanceMonitor()
/// )
/// 
/// let request = URLRequest(url: url)
/// let (data, response) = try await client.data(for: request)
/// ```
public actor EnhancedNetworkClient: NetworkClientProtocol {
    /// The underlying URLSession for network operations
    private let session: URLSession
    
    /// Configuration for the network client
    private let configuration: DIConfiguration
    
    /// Retry strategy for failed requests
    private let retryStrategy: RetryStrategy
    
    /// Optional performance monitor
    private let monitor: PerformanceMonitorProtocol?
    
    /// Request counter for tracking
    private var requestCount: Int = 0
    
    /// Initializes a new enhanced network client
    /// 
    /// - Parameters:
    ///   - configuration: Configuration settings for the client
    ///   - retryStrategy: Strategy for retrying failed requests (default: exponential backoff)
    ///   - monitor: Optional performance monitor for collecting metrics
    public init(
        configuration: DIConfiguration,
        retryStrategy: RetryStrategy = ExponentialBackoffRetryStrategy(),
        monitor: PerformanceMonitorProtocol? = nil
    ) {
        // Configure URLSession with optimized settings
        let sessionConfig = URLSessionConfiguration.default
        
        // Connection pooling settings
        sessionConfig.httpMaximumConnectionsPerHost = configuration.maxConcurrentDownloads
        sessionConfig.timeoutIntervalForRequest = configuration.downloadTimeout
        sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
        
        // Cache configuration
        #if canImport(Darwin)
        sessionConfig.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB memory cache
            diskCapacity: 100 * 1024 * 1024,    // 100 MB disk cache
            directory: nil
        )
        #else
        sessionConfig.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: nil
        )
        #endif
        sessionConfig.requestCachePolicy = .returnCacheDataElseLoad
        
        // Cookie and credential management
        sessionConfig.httpCookieAcceptPolicy = .never
        sessionConfig.httpShouldSetCookies = false
        
        // Additional headers
        var additionalHeaders = configuration.defaultHeaders
        additionalHeaders["Accept-Encoding"] = "gzip, deflate"
        sessionConfig.httpAdditionalHeaders = additionalHeaders
        
        self.session = URLSession(configuration: sessionConfig)
        self.configuration = configuration
        self.retryStrategy = retryStrategy
        self.monitor = monitor
    }
    
    /// Performs a network request with automatic retry logic
    /// 
    /// This method executes a network request and automatically retries on
    /// transient failures according to the configured retry strategy.
    /// 
    /// - Parameter request: The URL request to execute
    /// 
    /// - Returns: A tuple containing the response data and URL response
    /// 
    /// - Throws: 
    ///   - `NetworkError` for various network failures
    ///   - The last error encountered if all retries fail
    public nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await performRequestWithRetry(request: request)
    }
    
    /// Performs the actual request with retry logic
    /// 
    /// - Parameter request: The URL request to execute
    /// 
    /// - Returns: A tuple containing the response data and URL response
    /// 
    /// - Throws: Network errors or the last error after all retries fail
    private func performRequestWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error?
        let maxAttempts = retryStrategy.maxAttempts + 1 // +1 for initial attempt
        
        for attempt in 0..<maxAttempts {
            do {
                // Track request start time
                let startTime = Date()
                
                // Increment request counter
                incrementRequestCount()
                
                // Execute the request
                let (data, response) = try await session.data(for: request)
                
                // Calculate duration
                let duration = Date().timeIntervalSince(startTime)
                
                // Record metrics
                await recordMetrics(
                    duration: duration,
                    dataSize: data.count,
                    attempt: attempt,
                    success: true
                )
                
                // Validate the response
                try validateResponse(response, data: data, url: request.url!)
                
                // Log success
                if attempt > 0 {
                    Logger.info(
                        "Request succeeded after \(attempt) retries",
                        category: .network
                    )
                }
                
                return (data, response)
                
            } catch {
                lastError = error
                
                // Log the error
                Logger.debug(
                    "Request failed (attempt \(attempt + 1)/\(maxAttempts)): \(error.localizedDescription)",
                    category: .network
                )
                
                // Check if we should retry
                guard attempt < maxAttempts - 1,
                      retryStrategy.shouldRetry(error: error, attempt: attempt) else {
                    // No more retries, throw the error
                    await recordMetrics(
                        duration: 0,
                        dataSize: 0,
                        attempt: attempt,
                        success: false
                    )
                    break
                }
                
                // Calculate and wait for retry delay
                let delay = retryStrategy.delayBeforeRetry(attempt: attempt)
                Logger.debug(
                    "Retrying in \(String(format: "%.2f", delay)) seconds...",
                    category: .network
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted, throw the last error
        throw lastError ?? NetworkError.unknownError()
    }
    
    /// Validates the HTTP response
    /// 
    /// - Parameters:
    ///   - response: The URL response to validate
    ///   - data: The response data
    ///   - url: The request URL
    /// 
    /// - Throws: `NetworkError` if validation fails
    private func validateResponse(_ response: URLResponse, data: Data, url: URL) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(url)
        }
        
        let statusCode = httpResponse.statusCode
        
        switch statusCode {
        case 200...299:
            // Success - no error
            return
            
        case 400...499:
            // Client errors - don't retry
            throw NetworkError.clientError(url,statusCode: statusCode)
            
        case 500...599:
            // Server errors - can retry
            throw NetworkError.serverError(url, statusCode: statusCode)
            
        default:
            // Unknown status code
            throw NetworkError.invalidResponse(url)
        }
    }
    
    /// Records performance metrics
    /// 
    /// - Parameters:
    ///   - duration: Request duration in seconds
    ///   - dataSize: Size of response data in bytes
    ///   - attempt: The attempt number
    ///   - success: Whether the request was successful
    private func recordMetrics(
        duration: TimeInterval,
        dataSize: Int,
        attempt: Int,
        success: Bool
    ) async {
        guard let monitor = monitor else { return }
        
        await monitor.record(
            name: "network.request.duration",
            value: duration,
            unit: "seconds"
        )
        
        await monitor.record(
            name: "network.request.size",
            value: Double(dataSize),
            unit: "bytes"
        )
        
        await monitor.record(
            name: "network.request.attempts",
            value: Double(attempt + 1),
            unit: "count"
        )
        
        if duration > 0 {
            let speed = Double(dataSize) / duration
            await monitor.record(
                name: "network.download.speed",
                value: speed,
                unit: "bytes/sec"
            )
        }
        
        await monitor.record(
            name: success ? "network.request.success" : "network.request.failure",
            value: 1.0,
            unit: "count"
        )
    }
    
    /// Increments the request counter
    private func incrementRequestCount() {
        requestCount += 1
    }
    
    /// Gets the total number of requests made
    /// 
    /// - Returns: The total request count
    public func getRequestCount() -> Int {
        return requestCount
    }
    
    /// Resets the request counter
    public func resetRequestCount() {
        requestCount = 0
    }
}

// MARK: - Performance Monitor Protocol

/// Protocol for monitoring network performance
/// 
/// Implementations of this protocol can collect and analyze performance
/// metrics from network operations.
public protocol PerformanceMonitorProtocol: Sendable {
    /// Records a performance metric
    /// 
    /// - Parameters:
    ///   - name: The metric name
    ///   - value: The metric value
    ///   - unit: The unit of measurement
    func record(name: String, value: Double, unit: String) async
}