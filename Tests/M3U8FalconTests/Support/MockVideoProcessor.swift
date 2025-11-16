//
//  MockVideoProcessor.swift
//  M3U8FalconTests
//
//  Mock implementation of VideoProcessorProtocol for testing
//

import Foundation
@testable import M3U8Falcon

final class MockVideoProcessor: VideoProcessorProtocol, @unchecked Sendable {
    var combineSegmentsCalled = false
    var decryptSegmentCalled = false
    var decryptAndCombineSegmentsCalled = false
    var shouldFailCombine = false
    
    func combineSegments(in directory: URL, outputFile: URL) async throws {
        combineSegmentsCalled = true
        
        if shouldFailCombine {
            throw ProcessingError.conversionFailed("Mock combine failure")
        }
        
        // Create mock output file
        let mockData = "mock video data".data(using: .utf8)!
        try mockData.write(to: outputFile)
    }
    
    func decryptSegment(at url: URL, to outputURL: URL, keyURL: URL?) async throws {
        decryptSegmentCalled = true
        
        // Create mock decrypted file
        let mockData = "mock decrypted data".data(using: .utf8)!
        try mockData.write(to: outputURL)
    }
    
    func decryptAndCombineSegments(in directory: URL, with localM3U8FileName: String, outputFile: URL) async throws {
        decryptAndCombineSegmentsCalled = true
        
        if shouldFailCombine {
            throw ProcessingError.conversionFailed("Mock decrypt and combine failure")
        }
        
        // Create mock output file
        let mockData = "mock decrypted and combined video data".data(using: .utf8)!
        try mockData.write(to: outputFile)
    }
}

