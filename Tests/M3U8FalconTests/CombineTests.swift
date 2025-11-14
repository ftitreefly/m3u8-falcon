//
//  CombineTests.swift
//  M3U8FalconTests
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

@testable import M3U8Falcon

final class CombineTests: XCTestCase, @unchecked Sendable {

    var testContainer: DependencyContainer!
    var tempDirectory: URL!
    var fileSystem: FileSystemServiceProtocol!
    var videoSystem: VideoProcessorProtocol!
    var httpSystem: M3U8DownloaderProtocol!

    override func setUpWithError() throws {
        testContainer = DependencyContainer()
        testContainer.configure(with: DIConfiguration.performanceOptimized())
        
        videoSystem = try testContainer.resolve(VideoProcessorProtocol.self)
        httpSystem = try testContainer.resolve(M3U8DownloaderProtocol.self)
        
        fileSystem = try testContainer.resolve(FileSystemServiceProtocol.self)
        tempDirectory = try fileSystem.createTemporaryDirectory(nil)
    }

    override func tearDownWithError() throws {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        testContainer = nil
    }

    // MARK: - Helper Methods

    /// Download test ts segments from network
    private func downloadTestSegments(count: Int = 3) async throws -> URL {
        guard await canReachAppleTestServer() else {
            throw XCTSkip("Skipping: network not available or Apple test server unreachable")
        }
        
        let segmentBaseURL = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/"
        let testSegmentURLs = (0..<count).map {
            URL(string: "\(segmentBaseURL)fileSequence\($0).ts")!
        }
        
        let headers = [
            "User-Agent": "M3U8Falcon-Test/1.0",
            "Accept": "*/*"
        ]
        
        let segmentsDirectory = tempDirectory.appendingPathComponent("segments")
        try fileSystem.createDirectory(at: segmentsDirectory, withIntermediateDirectories: true)
        
        try await httpSystem.downloadSegments(
            at: testSegmentURLs,
            to: segmentsDirectory,
            headers: headers
        )
        
        let files = try fileSystem.contentsOfDirectory(at: segmentsDirectory)
        XCTAssertGreaterThanOrEqual(files.count, count, "Should have downloaded at least \(count) files")
        
        return segmentsDirectory
    }

    /// Check if ffmpeg is available in common locations or PATH
    private func isFFmpegAvailable() -> Bool {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["FFMPEG_PATH"], FileManager.default.isExecutableFile(atPath: explicit) {
            return true
        }
        let candidates = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]
        if candidates.contains(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return true
        }
        let whichURL = URL(fileURLWithPath: "/usr/bin/which")
        guard FileManager.default.isExecutableFile(atPath: whichURL.path) else { return false }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = whichURL
        process.arguments = ["ffmpeg"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            let out = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !out.isEmpty && FileManager.default.isExecutableFile(atPath: out)
        } catch {
            return false
        }
    }

    /// Quick reachability check for Apple's public test server
    private func canReachAppleTestServer(timeoutSeconds: TimeInterval = 5) async -> Bool {
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/fileSequence0.ts") else {
            return false
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        let session = URLSession(configuration: config)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        do {
            _ = try await session.data(for: request)
            return true
        } catch {
            return false
        }
    }

    /// Common helper to run a combine test for N segments
    private func runCombineTest(segmentsCount: Int, outputName: String) async throws {
        guard isFFmpegAvailable() else {
            throw XCTSkip("Skipping combine test: FFmpeg may be unavailable")
        }
        let segmentsDirectory = try await downloadTestSegments(count: segmentsCount)
        let outputFile = tempDirectory.appendingPathComponent(outputName)
        try await videoSystem.combineSegments(in: segmentsDirectory, outputFile: outputFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputFile.path), "Combined output file should exist")
        let attributes = try FileManager.default.attributesOfItem(atPath: outputFile.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Output file size should be greater than 0")
    }

    // MARK: - DefaultVideoProcessor Tests

    /// Test DefaultVideoProcessor basic functionality
    func testDefaultVideoProcessorBasicFunctionality() async throws {
        XCTAssertNotNil(videoSystem, "VideoProcessor should be properly resolved")

        // Verify VideoProcessor is DefaultVideoProcessor type
        guard videoSystem is DefaultVideoProcessor else {
            XCTFail("VideoProcessor should be DefaultVideoProcessor type")
            return
        }

        // DefaultVideoProcessor basic functionality verification passed
    }

    /// Test video segment combination functionality with 1 segment
    func testCombineSingleSegment() async throws {
        try await runCombineTest(segmentsCount: 1, outputName: "combined_single.mp4")
    }

    /// Test video segment combination functionality with 2 segments
    func testCombineTwoSegments() async throws {
        try await runCombineTest(segmentsCount: 2, outputName: "combined_two.mp4")
    }

    /// Test video segment combination functionality with 3 segments
    func testCombineThreeSegments() async throws {
        try await runCombineTest(segmentsCount: 3, outputName: "combined_three.mp4")
    }

    /// Test error handling with empty directory
    func testErrorHandlingEmptyDirectory() async throws {
        // Starting error handling test with empty directory

        // Test handling of empty directory
        let emptyDirectory = tempDirectory.appendingPathComponent("empty_segments")
        try FileManager.default.createDirectory(at: emptyDirectory, withIntermediateDirectories: true)
        
        let outputFile = tempDirectory.appendingPathComponent("error_output.mp4")

        do {
            try await videoSystem.combineSegments(in: emptyDirectory, outputFile: outputFile)
            XCTFail("Should throw error because directory is empty")
        } catch {
            // Error handling test passed
            XCTAssertTrue(error is ProcessingError, "Should throw ProcessingError type error")
        }
    }

    /// Test error handling with non-existent directory
    func testErrorHandlingNonExistentDirectory() async throws {
        // Starting error handling test with non-existent directory

        // Test handling of non-existent directory
        let nonExistentDirectory = tempDirectory.appendingPathComponent("non_existent_segments")
        let outputFile = tempDirectory.appendingPathComponent("error_output2.mp4")

        do {
            try await videoSystem.combineSegments(in: nonExistentDirectory, outputFile: outputFile)
            XCTFail("Should throw error because directory does not exist")
        } catch {
            // Error handling test passed
            // The error could be various types depending on the implementation
            // Just verify that an error was thrown
            XCTAssertTrue(true, "Error was correctly thrown for non-existent directory")
        }
    }
}
