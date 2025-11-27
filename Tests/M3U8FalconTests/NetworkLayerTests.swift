//
//  NetworkLayerTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon
import Testing

/// Tests for the enhanced network layer
@Suite("Network Layer Tests")
final class NetworkLayerTests {
    
    // MARK: - Retry Strategy Tests
    
    @Test("Exponential backoff calculation")
    func exponentialBackoffCalculation() {
        let strategy = ExponentialBackoffRetryStrategy(
            baseDelay: 1.0,
            maxDelay: 30.0,
            maxAttempts: 5
        )
        
        let delay0 = strategy.delayBeforeRetry(attempt: 0)
        #expect(delay0 >= 0.9 && delay0 <= 1.1)
        
        let delay1 = strategy.delayBeforeRetry(attempt: 1)
        #expect(delay1 >= 1.8 && delay1 <= 2.2)
        
        let delay2 = strategy.delayBeforeRetry(attempt: 2)
        #expect(delay2 >= 3.6 && delay2 <= 4.4)
        
        let delay10 = strategy.delayBeforeRetry(attempt: 10)
        #expect(delay10 <= 30.0)
    }
    
    @Test("Retryable errors")
    func retryableErrors() {
        let strategy = ExponentialBackoffRetryStrategy(maxAttempts: 3)
        
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        #expect(strategy.shouldRetry(error: timeoutError, attempt: 0))
        #expect(strategy.shouldRetry(error: timeoutError, attempt: 1))
        #expect(strategy.shouldRetry(error: timeoutError, attempt: 2))
        #expect(!strategy.shouldRetry(error: timeoutError, attempt: 3))
        
        let clientError = NetworkError.clientError(
            URL(string: "https://example.com")!,
            statusCode: 404
        )
        #expect(!strategy.shouldRetry(error: clientError, attempt: 0))
        
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        #expect(strategy.shouldRetry(error: serverError, attempt: 0))
    }
    
    @Test("Linear backoff strategy")
    func linearBackoffStrategy() {
        let strategy = LinearBackoffRetryStrategy(
            baseDelay: 2.0,
            maxAttempts: 3
        )
        
        #expect(strategy.delayBeforeRetry(attempt: 0) == 2.0)
        #expect(strategy.delayBeforeRetry(attempt: 1) == 4.0)
        #expect(strategy.delayBeforeRetry(attempt: 2) == 6.0)
    }
    
    @Test("Fixed delay strategy")
    func fixedDelayStrategy() {
        let strategy = FixedDelayRetryStrategy(
            delay: 3.0,
            maxAttempts: 5
        )
        
        #expect(strategy.delayBeforeRetry(attempt: 0) == 3.0)
        #expect(strategy.delayBeforeRetry(attempt: 1) == 3.0)
        #expect(strategy.delayBeforeRetry(attempt: 5) == 3.0)
    }
    
    @Test("No retry strategy")
    func noRetryStrategy() {
        let strategy = NoRetryStrategy()
        
        #expect(strategy.maxAttempts == 0)
        #expect(!strategy.shouldRetry(
            error: NetworkError.timeout(URL(string: "https://example.com")!),
            attempt: 0
        ))
        #expect(strategy.delayBeforeRetry(attempt: 0) == 0)
    }
    
    // MARK: - Network Error Tests
    
    @Test("Network error codes")
    func networkErrorCodes() {
        let connectionError = NetworkError.connectionFailed(
            URL(string: "https://example.com")!,
            underlying: URLError(.notConnectedToInternet)
        )
        #expect(connectionError.code == 1001)
        
        let invalidURLError = NetworkError.invalidURL("not a url")
        #expect(invalidURLError.code == 1002)
        
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        #expect(timeoutError.code == 1003)
        
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        #expect(serverError.code == 1004)
        
        let clientError = NetworkError.clientError(
            URL(string: "https://example.com")!,
            statusCode: 404
        )
        #expect(clientError.code == 1005)
    }
    
    @Test("Network error recovery suggestions")
    func networkErrorRecoverySuggestions() {
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        #expect(timeoutError.recoverySuggestion != nil)
        #expect(timeoutError.recoverySuggestion!.contains("timeout"))
        
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        #expect(serverError.recoverySuggestion != nil)
        #expect(serverError.recoverySuggestion!.contains("retried"))
    }
    
    // MARK: - Default Network Client Tests
    
    @Test("Default network client initialization")
    func defaultNetworkClientInitialization() async {
        let fileSystem = DefaultFileSystemService()
        let config = DIConfiguration.performanceOptimized()
        let client = DefaultNetworkClient(
            configuration: config,
            retryStrategy: ExponentialBackoffRetryStrategy(),
            fileSystem: fileSystem
        )
        
        let requestCount = await client.getRequestCount()
        #expect(requestCount == 0)
    }
}
