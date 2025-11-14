//
//  XCTestManifests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/13.
//  Updated on 2025/11/14 for Linux async test compatibility
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    // Note: Most tests in M3U8FalconTests are async and cannot be included
    // in Linux test manifests due to XCTest limitations.
    // Tests with 'throws' are wrapped in non-throwing wrapper functions to avoid
    // @Sendable type casting issues on Linux.
    // Tests with @Sendable closures or @unchecked Sendable classes are excluded.
    return [
        testCase(ParseTests.allTestsParseTests),
        testCase(PerformanceOptimizedTests.allTestsPerformanceOptimizedTests),
        testCase(NetworkLayerTests.allTestsNetworkLayerTests),
        testCase(DownloadTests.allTestsDownloadTests),
    ]
}
#endif

#if !canImport(ObjectiveC)
// Note: The following test suites contain only async tests and are excluded on Linux:
// - CombineTests (6 async tests) - all excluded
// - MemoryManagementTests (9 async tests) - all excluded
// - NetworkTests (6 async tests) - all excluded
// - TaskManagerTests (10 async tests) - all excluded
// 
// Partially included test suites (only synchronous tests included):
// - NetworkLayerTests: 8 synchronous tests included, 4 async tests excluded
// - IntegrationTests: 4 synchronous tests included, 5 async tests excluded
// - DownloadTests: 1 synchronous test included, 8 async tests excluded

// Wrapper functions for ParseTests to avoid @Sendable type casting issues on Linux
// All ParseTests methods have 'throws', which causes casting problems on Linux
extension ParseTests {
    // Non-throwing wrappers for throwing test methods
    // Using @nonobjc to prevent Swift from automatically adding @Sendable
    @nonobjc func testDifferentPlaylistTypesWrapper() {
        do {
            try testDifferentPlaylistTypes()
        } catch {
            XCTFail("testDifferentPlaylistTypes failed: \(error)")
        }
    }
    
    @nonobjc func testParseEmptyPlaylistWrapper() {
        do {
            try testParseEmptyPlaylist()
        } catch {
            XCTFail("testParseEmptyPlaylist failed: \(error)")
        }
    }
    
    @nonobjc func testParseInvalidPlaylistWrapper() {
        do {
            try testParseInvalidPlaylist()
        } catch {
            XCTFail("testParseInvalidPlaylist failed: \(error)")
        }
    }
    
    @nonobjc func testParseMasterPlaylistWrapper() {
        do {
            try testParseMasterPlaylist()
        } catch {
            XCTFail("testParseMasterPlaylist failed: \(error)")
        }
    }
    
    @nonobjc func testParseMasterPlaylistWithMediaWrapper() {
        do {
            try testParseMasterPlaylistWithMedia()
        } catch {
            XCTFail("testParseMasterPlaylistWithMedia failed: \(error)")
        }
    }
    
    @nonobjc func testParseMediaPlaylistWrapper() {
        do {
            try testParseMediaPlaylist()
        } catch {
            XCTFail("testParseMediaPlaylist failed: \(error)")
        }
    }
    
    @nonobjc func testParseMediaPlaylistWithKeyWrapper() {
        do {
            try testParseMediaPlaylistWithKey()
        } catch {
            XCTFail("testParseMediaPlaylistWithKey failed: \(error)")
        }
    }
    
    @nonobjc func testParserCancelWrapper() {
        do {
            try testParserCancel()
        } catch {
            XCTFail("testParserCancel failed: \(error)")
        }
    }
    
    @nonobjc func testParserPerformanceWrapper() {
        do {
            try testParserPerformance()
        } catch {
            XCTFail("testParserPerformance failed: \(error)")
        }
    }
    
    @nonobjc func testParserResetWrapper() {
        do {
            try testParserReset()
        } catch {
            XCTFail("testParserReset failed: \(error)")
        }
    }
    
    nonisolated(unsafe) static let allTestsParseTests: [(String, (ParseTests) -> () -> Void)] = [
        ("testDifferentPlaylistTypes", { $0.testDifferentPlaylistTypesWrapper }),
        ("testParseEmptyPlaylist", { $0.testParseEmptyPlaylistWrapper }),
        ("testParseInvalidPlaylist", { $0.testParseInvalidPlaylistWrapper }),
        ("testParseMasterPlaylist", { $0.testParseMasterPlaylistWrapper }),
        ("testParseMasterPlaylistWithMedia", { $0.testParseMasterPlaylistWithMediaWrapper }),
        ("testParseMediaPlaylist", { $0.testParseMediaPlaylistWrapper }),
        ("testParseMediaPlaylistWithKey", { $0.testParseMediaPlaylistWithKeyWrapper }),
        ("testParserCancel", { $0.testParserCancelWrapper }),
        ("testParserPerformance", { $0.testParserPerformanceWrapper }),
        ("testParserReset", { $0.testParserResetWrapper }),
    ]
}

// Wrapper functions for PerformanceOptimizedTests to avoid @Sendable type casting issues on Linux
// Some PerformanceOptimizedTests methods have 'throws', which causes casting problems on Linux
extension PerformanceOptimizedTests {
    // Non-throwing wrappers for throwing test methods
    // Using @nonobjc to prevent Swift from automatically adding @Sendable
    @nonobjc func testBasicInitializationWrapper() {
        do {
            try testBasicInitialization()
        } catch {
            XCTFail("testBasicInitialization failed: \(error)")
        }
    }
    
    @nonobjc func testConfigurationValidationWrapper() {
        do {
            try testConfigurationValidation()
        } catch {
            XCTFail("testConfigurationValidation failed: \(error)")
        }
    }
    
    @nonobjc func testFileSystemOperationsWrapper() {
        do {
            try testFileSystemOperations()
        } catch {
            XCTFail("testFileSystemOperations failed: \(error)")
        }
    }
    
    @nonobjc func testCommandExecutorCreationWrapper() {
        do {
            try testCommandExecutorCreation()
        } catch {
            XCTFail("testCommandExecutorCreation failed: \(error)")
        }
    }
    
    @nonobjc func testDependencyContainerBasicsWrapper() {
        do {
            try testDependencyContainerBasics()
        } catch {
            XCTFail("testDependencyContainerBasics failed: \(error)")
        }
    }
    
    @nonobjc func testM3U8ParserServiceDirectWrapper() {
        do {
            try testM3U8ParserServiceDirect()
        } catch {
            XCTFail("testM3U8ParserServiceDirect failed: \(error)")
        }
    }
    
    nonisolated(unsafe) static let allTestsPerformanceOptimizedTests: [(String, (PerformanceOptimizedTests) -> () -> Void)] = [
        ("testBasicInitialization", { $0.testBasicInitializationWrapper }),
        ("testCommandExecutorCreation", { $0.testCommandExecutorCreationWrapper }),
        ("testConfigurationValidation", { $0.testConfigurationValidationWrapper }),
        ("testDependencyContainerBasics", { $0.testDependencyContainerBasicsWrapper }),
        ("testDownloadAPISignature", { $0.testDownloadAPISignature }),
        ("testDownloadConfigurationTypes", { $0.testDownloadConfigurationTypes }),
        ("testDownloadProgressCalculation", { $0.testDownloadProgressCalculation }),
        ("testFileSystemOperations", { $0.testFileSystemOperationsWrapper }),
        ("testM3U8ContentValidation", { $0.testM3U8ContentValidation }),
        ("testM3U8ParserServiceDirect", { $0.testM3U8ParserServiceDirectWrapper }),
        ("testPerformanceOptimizedConfiguration", { $0.testPerformanceOptimizedConfiguration }),
        ("testTaskStatusEnum", { $0.testTaskStatusEnum }),
        ("testURLValidationLogic", { $0.testURLValidationLogic }),
    ]
}

// Wrapper functions for NetworkLayerTests - only synchronous tests included
extension NetworkLayerTests {
    nonisolated(unsafe) static let allTestsNetworkLayerTests: [(String, (NetworkLayerTests) -> () -> Void)] = [
        ("testExponentialBackoffCalculation", { $0.testExponentialBackoffCalculation }),
        ("testRetryableErrors", { $0.testRetryableErrors }),
        ("testLinearBackoffStrategy", { $0.testLinearBackoffStrategy }),
        ("testFixedDelayStrategy", { $0.testFixedDelayStrategy }),
        ("testNoRetryStrategy", { $0.testNoRetryStrategy }),
        ("testNetworkErrorCodes", { $0.testNetworkErrorCodes }),
        ("testNetworkErrorRecoverySuggestions", { $0.testNetworkErrorRecoverySuggestions }),
    ]
    // Excluded async tests:
    // - testEnhancedNetworkClientInitialization
    // - testEnhancedNetworkClientRequestCounting
    // - testSuccessfulRequestWithoutRetry
    // - testClientErrorNoRetry
    // - testPerformanceMonitorIntegration
}

// Wrapper functions for DownloadTests - only synchronous tests included
extension DownloadTests {
    @nonobjc func testPerformanceOptimizedConfigurationWrapper() {
        do {
            try testPerformanceOptimizedConfiguration()
        } catch {
            XCTFail("testPerformanceOptimizedConfiguration failed: \(error)")
        }
    }
    
    nonisolated(unsafe) static let allTestsDownloadTests: [(String, (DownloadTests) -> () -> Void)] = [
        ("testPerformanceOptimizedConfiguration", { $0.testPerformanceOptimizedConfigurationWrapper }),
    ]
    // Excluded async tests:
    // - testDownloadContentFromValidURL
    // - testDownloadM3U8Playlist
    // - testDownloadVideoSegments
    // - testSimpleStringResponseConcurrentDownloads
    // - testSimpleSegmentsConcurrentDownloads
    // - testDownloadToFileSystem
    // - testDownloadWithTimeout
    // - testDownloadQuickResponse
}
#endif
