//
//  XCTestManifests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/13.
//

import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(TaskManagerTests.allTests),
        testCase(M3U8ParserTests.allTests),
        testCase(DownloaderTests.allTests),
        testCase(FileSystemTests.allTests),
        testCase(TaskManagerTests.allTests),
        testCase(M3U8ParserTests.allTests),
        testCase(DownloaderTests.allTests),
        testCase(FileSystemTests.allTests),
    ]
}
#endif
