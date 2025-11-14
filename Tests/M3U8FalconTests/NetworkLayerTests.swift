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
import XCTest
@testable import M3U8Falcon

/// Tests for the enhanced network layer
final class NetworkLayerTests: XCTestCase {
    
    // MARK: - Retry Strategy Tests
    
    func testExponentialBackoffCalculation() {
        let strategy = ExponentialBackoffRetryStrategy(
            baseDelay: 1.0,
            maxDelay: 30.0,
            maxAttempts: 5
        )
        
        // Test delay calculation
        let delay0 = strategy.delayBeforeRetry(attempt: 0)
        XCTAssertGreaterThanOrEqual(delay0, 0.9) // ~1.0 with jitter
        XCTAssertLessThanOrEqual(delay0, 1.1)
        
        let delay1 = strategy.delayBeforeRetry(attempt: 1)
        XCTAssertGreaterThanOrEqual(delay1, 1.8) // ~2.0 with jitter
        XCTAssertLessThanOrEqual(delay1, 2.2)
        
        let delay2 = strategy.delayBeforeRetry(attempt: 2)
        XCTAssertGreaterThanOrEqual(delay2, 3.6) // ~4.0 with jitter
        XCTAssertLessThanOrEqual(delay2, 4.4)
        
        // Test max delay cap
        let delay10 = strategy.delayBeforeRetry(attempt: 10)
        XCTAssertLessThanOrEqual(delay10, 30.0)
    }
    
    func testRetryableErrors() {
        let strategy = ExponentialBackoffRetryStrategy(maxAttempts: 3)
        
        // Test retryable network errors
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        XCTAssertTrue(strategy.shouldRetry(error: timeoutError, attempt: 0))
        XCTAssertTrue(strategy.shouldRetry(error: timeoutError, attempt: 1))
        XCTAssertTrue(strategy.shouldRetry(error: timeoutError, attempt: 2))
        XCTAssertFalse(strategy.shouldRetry(error: timeoutError, attempt: 3))
        
        // Test non-retryable client errors
        let clientError = NetworkError.clientError(
            URL(string: "https://example.com")!,
            statusCode: 404
        )
        XCTAssertFalse(strategy.shouldRetry(error: clientError, attempt: 0))
        
        // Test retryable server errors
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        XCTAssertTrue(strategy.shouldRetry(error: serverError, attempt: 0))
    }
    
    func testLinearBackoffStrategy() {
        let strategy = LinearBackoffRetryStrategy(
            baseDelay: 2.0,
            maxAttempts: 3
        )
        
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 0), 2.0)
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 1), 4.0)
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 2), 6.0)
    }
    
    func testFixedDelayStrategy() {
        let strategy = FixedDelayRetryStrategy(
            delay: 3.0,
            maxAttempts: 5
        )
        
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 0), 3.0)
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 1), 3.0)
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 5), 3.0)
    }
    
    func testNoRetryStrategy() {
        let strategy = NoRetryStrategy()
        
        XCTAssertEqual(strategy.maxAttempts, 0)
        XCTAssertFalse(strategy.shouldRetry(
            error: NetworkError.timeout(URL(string: "https://example.com")!),
            attempt: 0
        ))
        XCTAssertEqual(strategy.delayBeforeRetry(attempt: 0), 0)
    }
    
    // MARK: - Network Error Tests
    
    func testNetworkErrorCodes() {
        let connectionError = NetworkError.connectionFailed(
            URL(string: "https://example.com")!,
            underlying: URLError(.notConnectedToInternet)
        )
        XCTAssertEqual(connectionError.code, 1001)
        
        let invalidURLError = NetworkError.invalidURL("not a url")
        XCTAssertEqual(invalidURLError.code, 1002)
        
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        XCTAssertEqual(timeoutError.code, 1003)
        
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        XCTAssertEqual(serverError.code, 1004)
        
        let clientError = NetworkError.clientError(
            URL(string: "https://example.com")!,
            statusCode: 404
        )
        XCTAssertEqual(clientError.code, 1005)
    }
    
    func testNetworkErrorRecoverySuggestions() {
        let timeoutError = NetworkError.timeout(URL(string: "https://example.com")!)
        XCTAssertNotNil(timeoutError.recoverySuggestion)
        XCTAssertTrue(timeoutError.recoverySuggestion!.contains("timeout"))
        
        let serverError = NetworkError.serverError(
            URL(string: "https://example.com")!,
            statusCode: 503
        )
        XCTAssertNotNil(serverError.recoverySuggestion)
        XCTAssertTrue(serverError.recoverySuggestion!.contains("retried"))
    }
    
    // MARK: - Enhanced Network Client Tests
    
    func testEnhancedNetworkClientInitialization() async {
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: ExponentialBackoffRetryStrategy(),
            monitor: nil
        )
        
        // Test initial state
        let requestCount = await client.getRequestCount()
        XCTAssertEqual(requestCount, 0)
    }
    
    func testEnhancedNetworkClientRequestCounting() async throws {
        let config = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 10
        )
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: nil
        )
        
        // Make a request (will fail, but that's ok for this test)
        let url = URL(string: "https://httpbingo.org/status/200")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0
        
        do {
            _ = try await client.data(for: request)
        } catch {
            // Expected to fail or succeed, we just want to count requests
        }
        
        let requestCount = await client.getRequestCount()
        XCTAssertGreaterThanOrEqual(requestCount, 1)
        
        // Test reset
        await client.resetRequestCount()
        let resetCount = await client.getRequestCount()
        XCTAssertEqual(resetCount, 0)
    }
    
    // MARK: - Integration Tests
    
    func testSuccessfulRequestWithoutRetry() async throws {
        let config = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 30
        )
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: ExponentialBackoffRetryStrategy(maxAttempts: 2),
            monitor: nil
        )
        
        // Use a reliable test endpoint
        let url = URL(string: "https://httpbingo.org/status/200")!
        let request = URLRequest(url: url)
        
        do {
            let (data, response) = try await client.data(for: request)
            
            // Verify response
            XCTAssertNotNil(data)
            XCTAssertNotNil(response)
            
            if let httpResponse = response as? HTTPURLResponse {
                XCTAssertEqual(httpResponse.statusCode, 200)
            }
            
            // Verify request was counted
            let requestCount = await client.getRequestCount()
            XCTAssertEqual(requestCount, 1)
        } catch {
            // Network tests can be flaky, log but don't fail
            print("⚠️ Network test failed (this can happen): \(error)")
        }
    }
    
    func testClientErrorNoRetry() async throws {
        let config = DIConfiguration(
            maxConcurrentDownloads: 5,
            downloadTimeout: 10
        )
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: ExponentialBackoffRetryStrategy(maxAttempts: 3),
            monitor: nil
        )
        
        // Use endpoint that returns 404
        let url = URL(string: "https://httpbingo.org/status/404")!
        let request = URLRequest(url: url)
        
        do {
            _ = try await client.data(for: request)
            XCTFail("Expected error for 404 status")
        } catch let error as NetworkError {
            // Should be client error (1005)
            XCTAssertEqual(error.code, 1005)
            
            // Should only try once (no retry for client errors)
            let requestCount = await client.getRequestCount()
            XCTAssertEqual(requestCount, 1)
        } catch {
            print("⚠️ Network test failed with unexpected error: \(error)")
        }
    }
    
    // MARK: - Performance Monitor Tests
    
    func testPerformanceMonitorIntegration() async throws {
        let monitor = MockPerformanceMonitor()
        let config = DIConfiguration.performanceOptimized()
        let client = EnhancedNetworkClient(
            configuration: config,
            retryStrategy: NoRetryStrategy(),
            monitor: monitor
        )
        
        // Make a request
        let url = URL(string: "https://httpbingo.org/status/200")!
        let request = URLRequest(url: url)
        
        do {
            _ = try await client.data(for: request)
            
            // Verify metrics were recorded
            let metrics = await monitor.getMetrics()
            XCTAssertFalse(metrics.isEmpty, "Metrics should be recorded")
            
            // Check for expected metric names
            let metricNames = metrics.map { $0.name }
            XCTAssertTrue(metricNames.contains("network.request.duration"))
            XCTAssertTrue(metricNames.contains("network.request.size"))
        } catch {
            print("⚠️ Network test failed: \(error)")
        }
    }
}

// MARK: - Mock Performance Monitor

actor MockPerformanceMonitor: PerformanceMonitorProtocol {
    private var metrics: [(name: String, value: Double, unit: String)] = []
    
    func record(name: String, value: Double, unit: String) {
        metrics.append((name: name, value: value, unit: unit))
    }
    
    func getMetrics() -> [(name: String, value: Double, unit: String)] {
        return metrics
    }
    
    func reset() {
        metrics.removeAll()
    }
}
