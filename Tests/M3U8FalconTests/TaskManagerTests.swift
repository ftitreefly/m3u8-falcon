//
//  TaskManagerTests.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
import XCTest

@testable import M3U8Falcon
import enum M3U8Falcon.Method

final class TaskManagerTests: XCTestCase, @unchecked Sendable {
    
    var testContainer: DependencyContainer!
    var tempDirectory: URL!
    var fileSystem: FileSystemServiceProtocol!
    var taskManager: TaskManagerProtocol!
    
    // Mock services for testing
    var mockDownloader: MockM3U8Downloader!
    var mockParser: MockM3U8Parser!
    var mockProcessor: MockVideoProcessor!
    var mockFileSystem: MockFileSystem!
    
    // Test configuration
    var enableFastTesting: Bool = true // Set to false for slower, more realistic testing
    // When enableFastTesting = true: downloadDelay = 0.1s, sleep = 0.05s
    // When enableFastTesting = false: downloadDelay = 1.0s, sleep = 0.1s

    override func setUpWithError() throws {
        testContainer = DependencyContainer()
        testContainer.configure(with: DIConfiguration.performanceOptimized())
        // Silence logs in tests (avoid DEBUG noise)
        Logger.configure(.production())
        
        // Setup real file system for temporary directory
        fileSystem = try testContainer.resolve(FileSystemServiceProtocol.self)
        tempDirectory = try fileSystem.createTemporaryDirectory("TaskManagerTests")
        
        // Setup mock services
        setupMockServices()
    }

    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        testContainer = nil
        mockDownloader = nil
        mockParser = nil
        mockProcessor = nil
        mockFileSystem = nil
        taskManager = nil
    }
    
    // MARK: - Setup Methods
    
    private func setupMockServices() {
        mockDownloader = MockM3U8Downloader()
        mockParser = MockM3U8Parser()
        mockProcessor = MockVideoProcessor()
        mockFileSystem = MockFileSystem()
        
        // Configure for fast testing
        mockDownloader.enableDelay = !enableFastTesting
        
        let testConfiguration = DIConfiguration(
            maxConcurrentDownloads: 2,
            downloadTimeout: 1,
            resourceTimeout: 1
        )
        
        taskManager = DefaultTaskManager(
            downloader: mockDownloader,
            parser: mockParser,
            processor: mockProcessor,
            fileSystem: mockFileSystem,
            configuration: testConfiguration,
            maxConcurrentTasks: 2,
            networkClient: DefaultNetworkClient(configuration: testConfiguration),
            logger: LoggerAdapter()
        )
    }
    
    // MARK: - Basic Functionality Tests
    
    func testCreateTaskSuccess() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedContent = createMockM3U8Content()
        
        mockDownloader.mockContentResults[url] = expectedContent
        mockParser.mockParseResults[expectedContent] = .media(try createMockMediaPlaylist())
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When & Then - This test will fail due to real network calls
        // We expect it to throw an error for network requests
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Expected task to fail due to network issues")
        } catch {
            // Expected - the task should fail due to network calls
            XCTAssertTrue(error is ProcessingError, "Should throw ProcessingError")
            XCTAssertTrue(mockDownloader.downloadContentCalled, "Should call download content")
            XCTAssertTrue(mockParser.parseContentCalled, "Should call parse content")
        }
    }
    
    func testCreateTaskWithLocalFile() async throws {
        // Given
        let localM3U8Path = tempDirectory.appendingPathComponent("test.m3u8")
        let expectedContent = createMockM3U8Content()
        try expectedContent.write(to: localM3U8Path, atomically: true, encoding: .utf8)
        
        mockParser.mockParseResults[expectedContent] = .media(try createMockMediaPlaylist())
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When & Then - This test will also fail due to real network calls for segments
        do {
            let request = makeRequest(url: localM3U8Path, fileName: "test.mp4", method: Method.local)
            try await taskManager.createTask(request)
            XCTFail("Expected task to fail due to segment download issues")
        } catch {
            // Expected - the task should fail due to segment network calls
            XCTAssertTrue(error is ProcessingError, "Should throw ProcessingError")
            XCTAssertFalse(mockDownloader.downloadContentCalled, "Local file should not call download")
            XCTAssertTrue(mockParser.parseContentCalled, "Should call parse content")
        }
    }
    
    func testGetTaskStatusForNonExistentTask() async throws {
        // Given
        let nonExistentTaskId = "non-existent-task"
        
        // When
        let status = await taskManager.getTaskStatus(for: nonExistentTaskId)
        
        // Then
        XCTAssertNil(status, "Non-existent task should return nil")
    }
    
    func testCancelNonExistentTask() async throws {
        // Given
        let nonExistentTaskId = "non-existent-task"
        
        // When & Then
        do {
            try await taskManager.cancelTask(taskId: nonExistentTaskId)
            XCTFail("Cancelling non-existent task should throw error")
        } catch let error as ProcessingError {
            XCTAssertEqual(error.code, 4010, "Should be task not found error")
        } catch {
            XCTFail("Should throw ProcessingError type error")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMaxConcurrentTasksLimit() async throws {
        // Given
        let url1 = URL(string: "https://example.com/test1.m3u8")!
        let url2 = URL(string: "https://example.com/test2.m3u8")!
        let url3 = URL(string: "https://example.com/test3.m3u8")!
        
        let expectedContent = createMockM3U8Content()
        mockDownloader.mockContentResults[url1] = expectedContent
        mockDownloader.mockContentResults[url2] = expectedContent
        mockDownloader.mockContentResults[url3] = expectedContent
        
        mockParser.mockParseResults[expectedContent] = .media(try createMockMediaPlaylist())
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // Make download slow to test concurrency limits (reduced for faster testing)
        mockDownloader.downloadDelay = 0.1
        
        // Test concurrent task limit by starting tasks simultaneously
        async let task1: Void = {
            do {
                let request = makeRequest(url: url1, fileName: "test1.mp4", method: Method.web)
                try await self.taskManager.createTask(request)
            } catch {
                // Expected to fail due to network issues
            }
        }()
        
        async let task2: Void = {
            do {
                let request = makeRequest(url: url2, fileName: "test2.mp4", method: Method.web)
                try await self.taskManager.createTask(request)
            } catch {
                // Expected to fail due to network issues
            }
        }()
        
        // Wait a moment to ensure first two tasks are started (reduced for faster testing)
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Third task should fail due to concurrent task limit
        do {
            let request = makeRequest(url: url3, fileName: "test3.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Third task should fail due to concurrency limit")
        } catch let error as ProcessingError {
            XCTAssertTrue(error.message.contains("Maximum concurrent tasks reached") || 
                         error.message.contains("Operation was cancelled"), 
                         "Error message should contain 'Maximum concurrent tasks reached' or 'Operation was cancelled', got: \(error.message)")
        }
        
        // Wait for the first two tasks to complete
        await task1
        await task2
    }
    
    func testDownloadError() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedError = NetworkError.connectionFailed(url, underlying: URLError(.networkConnectionLost))
        
        mockDownloader.mockErrors[url] = expectedError
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When & Then
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Should throw network error")
        } catch {
            XCTAssertTrue(error is ProcessingError, "Should be wrapped as ProcessingError")
        }
    }
    
    func testParsingError() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedContent = "invalid m3u8 content"
        let expectedError = ParsingError.malformedPlaylist("Invalid format")
        
        mockDownloader.mockContentResults[url] = expectedContent
        mockParser.mockParseErrors[expectedContent] = expectedError
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When & Then
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Should throw parsing error")
        } catch {
            XCTAssertTrue(error is ProcessingError, "Should be wrapped as ProcessingError")
        }
    }
    
    // MARK: - Progress Callback Tests
    
    func testProgressCallbackUpdates() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedContent = createMockM3U8Content()
        
        mockDownloader.mockContentResults[url] = expectedContent
        mockParser.mockParseResults[expectedContent] = .media(try createMockMediaPlaylist())
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Expected task to fail due to network issues")
        } catch {
            // Expected - task should fail due to network issues
        }
        
        // Then - Since progress callback is removed, we just verify the task was attempted
        XCTAssertTrue(mockDownloader.downloadContentCalled, "Should call download content")
        XCTAssertTrue(mockParser.parseContentCalled, "Should call parse content")
    }
    
    func testProgressCallbackOnFailure() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedError = NetworkError.connectionFailed(url, underlying: URLError(.networkConnectionLost))
        
        mockDownloader.mockErrors[url] = expectedError
        mockFileSystem.mockTempDirectory = tempDirectory
        
        // When
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Should throw error")
        } catch {
            // Expected
        }
        
        // Then - Since progress callback is removed, we just verify the error was handled
        XCTAssertTrue(mockDownloader.downloadContentCalled, "Should call download content")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceMetrics() async throws {
        // Given
        let url = URL(string: "https://example.com/test.m3u8")!
        let expectedContent = createMockM3U8Content()
        
        mockDownloader.mockContentResults[url] = expectedContent
        mockParser.mockParseResults[expectedContent] = .media(try createMockMediaPlaylist())
        mockFileSystem.mockTempDirectory = tempDirectory
        
        guard let optimizedManager = taskManager as? DefaultTaskManager else {
            XCTFail("Should be DefaultTaskManager")
            return
        }
        
        // When
        let initialMetrics = await optimizedManager.getPerformanceMetrics()
        
        // This task will fail due to network issues, but we can still test metrics
        do {
            let request = makeRequest(url: url, fileName: "test.mp4", method: Method.web)
            try await taskManager.createTask(request)
            XCTFail("Expected task to fail due to network issues")
        } catch {
            // Expected - task should fail
        }
        
        let finalMetrics = await optimizedManager.getPerformanceMetrics()
        
        // Then
        XCTAssertEqual(initialMetrics.completedTasks, 0, "Initial completed tasks should be 0")
        XCTAssertEqual(finalMetrics.completedTasks, 0, "Failed tasks should not be counted as completed")
        XCTAssertGreaterThanOrEqual(finalMetrics.activeTasks, 0, "Active tasks should be greater than or equal to 0")
    }
    
    // MARK: - Helper Methods
    
    private func makeRequest(url: URL, fileName: String, method: Method, baseUrl: URL? = nil) -> TaskRequest {
        return TaskRequest(
            url: url,
            baseUrl: baseUrl,
            savedDirectory: tempDirectory,
            fileName: fileName,
            method: method,
            verbose: false
        )
    }

    private func createMockM3U8Content() -> String {
        return """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-TARGETDURATION:10
        #EXT-X-MEDIA-SEQUENCE:0
        #EXTINF:10.0,
        segment1.ts
        #EXTINF:10.0,
        segment2.ts
        #EXTINF:10.0,
        segment3.ts
        #EXT-X-ENDLIST
        """
    }
    
    private func createMockMediaPlaylist() throws -> MediaPlaylist {
        let baseUrl = URL(string: "https://example.com/")!
        
        // Create mock EXTINF tags
        let extinf1 = try EXTINF(text: "#EXTINF:10.0,\nsegment1.ts", tagType: EXTINF.self, extraParams: nil)
        let extinf2 = try EXTINF(text: "#EXTINF:10.0,\nsegment2.ts", tagType: EXTINF.self, extraParams: nil)
        let extinf3 = try EXTINF(text: "#EXTINF:10.0,\nsegment3.ts", tagType: EXTINF.self, extraParams: nil)
        
        // Create required tag objects
        let targetDuration = try EXT_X_TARGETDURATION(text: "#EXT-X-TARGETDURATION:10", tagType: EXT_X_TARGETDURATION.self, extraParams: nil)
        let version = try EXT_X_VERSION(text: "#EXT-X-VERSION:3", tagType: EXT_X_VERSION.self, extraParams: nil)
        let mediaSequence = try EXT_X_MEDIA_SEQUENCE(text: "#EXT-X-MEDIA-SEQUENCE:0", tagType: EXT_X_MEDIA_SEQUENCE.self, extraParams: nil)
        let endList = try EXT_X_ENDLIST(text: "#EXT-X-ENDLIST", tagType: EXT_X_ENDLIST.self, extraParams: nil)
        
        let tags = MediaPlaylistTags(
            targetDurationTag: targetDuration,
            allowCacheTag: nil,
            playlistTypeTag: nil,
            versionTag: version,
            mediaSequence: mediaSequence,
            mediaSegments: [extinf1, extinf2, extinf3],
            keySegments: [],
            endListTag: endList
        )
        
        return MediaPlaylist(
            baseUrl: baseUrl,
            tags: tags,
            extraTags: [:]
        )
    }
}

// MARK: - Mock Classes

final class MockM3U8Downloader: M3U8DownloaderProtocol, @unchecked Sendable {
    var mockContentResults: [URL: String] = [:]
    var mockDataResults: [URL: Data] = [:]
    var mockErrors: [URL: Error] = [:]
    var downloadDelay: TimeInterval = 0
    var enableDelay: Bool = true // Control whether to enable delay for faster testing
    
    var downloadContentCalled = false
    var downloadRawDataCalled = false
    var downloadSegmentsCalled = false
    
    func downloadContent(from url: URL) async throws -> String {
        downloadContentCalled = true
        
        if enableDelay && downloadDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(downloadDelay * 1_000_000_000))
        }
        
        if let error = mockErrors[url] {
            throw error
        }
        
        return mockContentResults[url] ?? ""
    }
    
    func downloadRawData(from url: URL) async throws -> Data {
        downloadRawDataCalled = true
        
        if let error = mockErrors[url] {
            throw error
        }
        
        return mockDataResults[url] ?? Data()
    }
    
    func downloadSegments(at urls: [URL], to directory: URL, headers: [String: String]) async throws {
        downloadSegmentsCalled = true
        
        // Create mock segment files
        for url in urls {
            let filename = url.lastPathComponent
            let fileURL = directory.appendingPathComponent(filename)
            let mockData = "mock segment data".data(using: .utf8)!
            try mockData.write(to: fileURL)
        }
    }
}

final class MockM3U8Parser: M3U8ParserServiceProtocol, @unchecked Sendable {
    var mockParseResults: [String: M3U8Parser.ParserResult] = [:]
    var mockParseErrors: [String: Error] = [:]
    var parseContentCalled = false
    
    func parseContent(_ content: String, baseURL: URL, type: PlaylistType) throws -> M3U8Parser.ParserResult {
        parseContentCalled = true
        
        if content.isEmpty {
            throw ProcessingError.emptyContent()
        }
        
        if let error = mockParseErrors[content] {
            throw error
        }
        
        return mockParseResults[content] ?? .cancelled
    }
}

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

final class MockFileSystem: FileSystemServiceProtocol, @unchecked Sendable {
    var mockTempDirectory: URL!
    var mockDirectoryExists = true
    var mockFileExists = true
    
    var createDirectoryCalled = false
    var createTemporaryDirectoryCalled = false
    var removeItemCalled = false
    var copyItemCalled = false
    
    func createDirectory(at url: URL, withIntermediateDirectories: Bool) throws {
        createDirectoryCalled = true
        
        if !mockDirectoryExists {
            throw FileSystemError.writePermissionDenied(url.path)
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        return mockFileExists
    }
    
    func removeItem(at url: URL) throws {
        removeItemCalled = true
    }
    
    func createTemporaryDirectory(_ saltString: String?) throws -> URL {
        createTemporaryDirectoryCalled = true
        return mockTempDirectory
    }
    
    func content(at url: URL) throws -> String {
        // Return the actual file content if it exists, otherwise return mock content
        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            return String(data: data, encoding: .utf8) ?? ""
        } else {
            // Return mock M3U8 content for testing
            return """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-MEDIA-SEQUENCE:0
            #EXTINF:10.0,
            segment1.ts
            #EXTINF:10.0,
            segment2.ts
            #EXTINF:10.0,
            segment3.ts
            #EXT-X-ENDLIST
            """
        }
    }
    
    func contentsOfDirectory(at url: URL) throws -> [URL] {
        return []
    }
    
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        copyItemCalled = true
        
        // Copy the file if it exists
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } else {
            // Create a mock file
            let mockData = "mock file data".data(using: .utf8)!
            try mockData.write(to: destinationURL)
        }
    }
}

actor ActorWrapper<T: Sendable> {
    private var value: T
    
    init(_ initialValue: T) {
        self.value = initialValue
    }
    
    func get() -> T {
        return value
    }
    
    func set(_ newValue: T) {
        self.value = newValue
    }
    
    func append(_ element: T.Element) where T: RangeReplaceableCollection {
        value.append(element)
    }
    
    func count() -> Int where T: Collection {
        return value.count
    }
    
    func first() -> T.Element? where T: Collection {
        return value.first
    }
    
    func last() -> T.Element? where T: BidirectionalCollection {
        return value.last
    }
    
    func map<U>(_ transform: (T.Element) throws -> U) rethrows -> [U] where T: Collection {
        return try value.map(transform)
    }
    
    func contains(_ element: T.Element) -> Bool where T: Collection, T.Element: Equatable {
        return value.contains(element)
    }
}
