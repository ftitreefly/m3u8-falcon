//
//  XCTestManifests.swift
//  M3U8FalconCLITests
//
//  Created by tree_fly on 2025/11/14.
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(YouTubeExtractorTests.allTestsYouTubeExtractorTests),
    ]
}
#endif

#if !canImport(ObjectiveC)
extension YouTubeExtractorTests {
    // Note: Async tests are not included in Linux test manifests due to XCTest limitations
    // The following tests are excluded (run only on macOS):
    // - test_extract_directLinks_whenPageContainsM3U8 (async)
    // - test_extract_playerResponse_mocked (async)
    nonisolated(unsafe) static let allTestsYouTubeExtractorTests: [(String, (YouTubeExtractorTests) -> () -> Void)] = [
        ("test_canHandle_youtubeDomains", { $0.test_canHandle_youtubeDomains }),
        ("test_getExtractorInfo", { $0.test_getExtractorInfo }),
        ("test_getSupportedDomains", { $0.test_getSupportedDomains }),
    ]
}
#endif

