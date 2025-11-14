//
//  LinuxMain.swift
//  M3U8Falcon Tests
//
//  Created by tree_fly on 2025/7/13.
//  Updated on 2025/11/14 for Linux test support
//

import XCTest

import M3U8FalconTests
import M3U8FalconCLITests

var tests = [XCTestCaseEntry]()
tests += M3U8FalconTests.allTests()
tests += M3U8FalconCLITests.allTests()
XCTMain(tests)
