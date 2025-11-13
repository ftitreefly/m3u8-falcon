//
//  RetryStrategy.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/9/30.
//

import Foundation

// MARK: - Retry Strategy Protocol

/// Protocol defining a retry strategy for failed network requests
/// 
/// This protocol allows for flexible retry logic implementation, supporting
/// different backoff algorithms and retry conditions.
/// 
/// ## Usage Example
/// ```swift
/// let strategy = ExponentialBackoffRetryStrategy()
/// 
/// if strategy.shouldRetry(error: error, attempt: 1) {
///     let delay = strategy.delayBeforeRetry(attempt: 1)
///     try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
///     // Retry the operation
/// }
/// ```
public protocol RetryStrategy: Sendable {
    /// Determines whether a retry should be attempted for the given error
    /// 
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - attempt: The current attempt number (0-based)
    /// 
    /// - Returns: `true` if the operation should be retried, `false` otherwise
    func shouldRetry(error: Error, attempt: Int) -> Bool
    
    /// Calculates the delay before the next retry attempt
    /// 
    /// - Parameter attempt: The current attempt number (0-based)
    /// 
    /// - Returns: The delay in seconds before the next retry
    func delayBeforeRetry(attempt: Int) -> TimeInterval
    
    /// The maximum number of retry attempts allowed
    var maxAttempts: Int { get }
}

// MARK: - Exponential Backoff Retry Strategy

/// Exponential backoff retry strategy with jitter
/// 
/// This strategy implements an exponential backoff algorithm with optional jitter
/// to prevent thundering herd problems. The delay between retries grows exponentially
/// with each attempt, up to a maximum delay.
/// 
/// ## Algorithm
/// ```
/// delay = min(baseDelay * (2 ^ attempt) + jitter, maxDelay)
/// ```
/// 
/// ## Usage Example
/// ```swift
/// let strategy = ExponentialBackoffRetryStrategy(
///     baseDelay: 0.5,
///     maxDelay: 30.0,
///     maxAttempts: 3,
///     jitterFactor: 0.1
/// )
/// ```
public struct ExponentialBackoffRetryStrategy: RetryStrategy {
    /// The base delay for the first retry attempt
    public let baseDelay: TimeInterval
    
    /// The maximum delay between retry attempts
    public let maxDelay: TimeInterval
    
    /// The maximum number of retry attempts
    public let maxAttempts: Int
    
    /// The jitter factor (0.0 to 1.0) to add randomness to delays
    public let jitterFactor: Double
    
    /// Initializes a new exponential backoff retry strategy
    /// 
    /// - Parameters:
    ///   - baseDelay: The base delay for the first retry (default: 0.5 seconds)
    ///   - maxDelay: The maximum delay between retries (default: 30.0 seconds)
    ///   - maxAttempts: The maximum number of retry attempts (default: 3)
    ///   - jitterFactor: The jitter factor for randomness (default: 0.1)
    public init(
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30.0,
        maxAttempts: Int = 3,
        jitterFactor: Double = 0.1
    ) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.maxAttempts = maxAttempts
        self.jitterFactor = max(0.0, min(1.0, jitterFactor))
    }
    
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Don't retry if we've exceeded max attempts
        guard attempt < maxAttempts else {
            return false
        }
        
        // Check if the error is retryable
        return isRetryableError(error)
    }
    
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        // Calculate exponential backoff delay
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        
        // Add jitter to prevent thundering herd
        let jitter = exponentialDelay * jitterFactor * Double.random(in: -1.0...1.0)
        
        // Apply maximum delay cap
        let delay = min(exponentialDelay + jitter, maxDelay)
        
        return max(0.0, delay) // Ensure non-negative delay
    }
    
    /// Determines if an error is retryable
    /// 
    /// This method checks if the error is a transient failure that can
    /// potentially succeed on retry.
    /// 
    /// - Parameter error: The error to check
    /// 
    /// - Returns: `true` if the error is retryable, `false` otherwise
    private func isRetryableError(_ error: Error) -> Bool {
        // Check for NetworkError types
        if let networkError = error as? NetworkError {
            // Retry on server errors (5xx) but not client errors (4xx)
            switch networkError.code {
            case 1001: // Network connection error
                return true
            case 1003: // Timeout
                return true
            case 1004: // Server error
                return true
            case 1005: // Client error (4xx) - don't retry
                return false
            case 1006: // Server error (5xx) - retry
                return true
            default:
                return false
            }
        }
        
        // Check for URLError types
        if let urlError = error as? URLError {
            let retryableCodes: [URLError.Code] = [
                .timedOut,
                .cannotConnectToHost,
                .networkConnectionLost,
                .notConnectedToInternet,
                .dnsLookupFailed,
                .cannotFindHost,
                .dataNotAllowed,
                .internationalRoamingOff
            ]
            return retryableCodes.contains(urlError.code)
        }
        
        // By default, don't retry unknown errors
        return false
    }
}

// MARK: - Linear Backoff Retry Strategy

/// Linear backoff retry strategy
/// 
/// This strategy implements a simple linear backoff where the delay increases
/// linearly with each attempt.
/// 
/// ## Algorithm
/// ```
/// delay = baseDelay * (attempt + 1)
/// ```
/// 
/// ## Usage Example
/// ```swift
/// let strategy = LinearBackoffRetryStrategy(
///     baseDelay: 1.0,
///     maxAttempts: 5
/// )
/// ```
public struct LinearBackoffRetryStrategy: RetryStrategy {
    /// The base delay for each retry attempt
    public let baseDelay: TimeInterval
    
    /// The maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Initializes a new linear backoff retry strategy
    /// 
    /// - Parameters:
    ///   - baseDelay: The base delay increment (default: 1.0 second)
    ///   - maxAttempts: The maximum number of retry attempts (default: 3)
    public init(
        baseDelay: TimeInterval = 1.0,
        maxAttempts: Int = 3
    ) {
        self.baseDelay = baseDelay
        self.maxAttempts = maxAttempts
    }
    
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else {
            return false
        }
        
        // Use the same retry logic as exponential backoff
        let exponentialStrategy = ExponentialBackoffRetryStrategy()
        return exponentialStrategy.shouldRetry(error: error, attempt: attempt)
    }
    
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        // Linear increase: delay = baseDelay * (attempt + 1)
        return baseDelay * Double(attempt + 1)
    }
}

// MARK: - Fixed Delay Retry Strategy

/// Fixed delay retry strategy
/// 
/// This strategy uses a constant delay between all retry attempts.
/// 
/// ## Usage Example
/// ```swift
/// let strategy = FixedDelayRetryStrategy(
///     delay: 2.0,
///     maxAttempts: 3
/// )
/// ```
public struct FixedDelayRetryStrategy: RetryStrategy {
    /// The fixed delay between retry attempts
    public let delay: TimeInterval
    
    /// The maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Initializes a new fixed delay retry strategy
    /// 
    /// - Parameters:
    ///   - delay: The fixed delay between retries (default: 1.0 second)
    ///   - maxAttempts: The maximum number of retry attempts (default: 3)
    public init(
        delay: TimeInterval = 1.0,
        maxAttempts: Int = 3
    ) {
        self.delay = delay
        self.maxAttempts = maxAttempts
    }
    
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else {
            return false
        }
        
        // Use the same retry logic as exponential backoff
        let exponentialStrategy = ExponentialBackoffRetryStrategy()
        return exponentialStrategy.shouldRetry(error: error, attempt: attempt)
    }
    
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        return delay
    }
}

// MARK: - No Retry Strategy

/// No retry strategy
/// 
/// This strategy never retries failed operations. Useful for operations
/// that should fail fast.
/// 
/// ## Usage Example
/// ```swift
/// let strategy = NoRetryStrategy()
/// ```
public struct NoRetryStrategy: RetryStrategy {
    public let maxAttempts: Int = 0
    
    public init() {}
    
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        return false
    }
    
    public func delayBeforeRetry(attempt: Int) -> TimeInterval {
        return 0
    }
}
