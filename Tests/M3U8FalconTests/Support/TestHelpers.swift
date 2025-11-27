//
//  TestHelpers.swift
//  M3U8FalconTests
//
//  Common test setup helpers to reduce code duplication
//

import Foundation
@testable import M3U8Falcon

/// Test environment setup helper
struct TestEnvironment {
    let container: DependencyContainer
    let configuration: DIConfiguration
    let mockNetworkClient: MockNetworkClient
    let fileSystem: FileSystemServiceProtocol
    let tempDirectory: URL
    
    /// Creates a test environment with default configuration
    static func create(
        configuration: DIConfiguration? = nil,
        containerConfig: DIConfiguration? = nil,
        tempDirectoryPrefix: String? = nil
    ) throws -> TestEnvironment {
        let config = configuration ?? DIConfiguration(
            maxConcurrentDownloads: 4,
            downloadTimeout: 5,
            resourceTimeout: 10
        )
        
        let container = DependencyContainer()
        container.configure(with: containerConfig ?? DIConfiguration.performanceOptimized())
        
        // Silence logs in tests (avoid DEBUG noise)
        Logger.configure(.production())
        
        let fileSystem = try container.resolve(FileSystemServiceProtocol.self)
        let tempDirectory = try fileSystem.createTemporaryDirectory(tempDirectoryPrefix)
        
        let mockNetworkClient = MockNetworkClient()
        M3U8TestFixtures.registerAllFixtures(on: mockNetworkClient)
        
        return TestEnvironment(
            container: container,
            configuration: config,
            mockNetworkClient: mockNetworkClient,
            fileSystem: fileSystem,
            tempDirectory: tempDirectory
        )
    }
    
    /// Creates a downloader with mock network client
    func createDownloader() -> M3U8DownloaderProtocol {
        DefaultM3U8Downloader(
            commandExecutor: NoopCommandExecutor(),
            configuration: configuration,
            networkClient: mockNetworkClient,
            fileSystem: fileSystem
        )
    }
    
    /// Registers mock services in the container
    func registerMockServices() {
        let networkClient = mockNetworkClient as NetworkClientProtocol
        let cmdExecutor = NoopCommandExecutor() as CommandExecutorProtocol
        
        container.registerSingleton(NetworkClientProtocol.self) { networkClient }
        container.registerSingleton(CommandExecutorProtocol.self) { cmdExecutor }
    }
    
    /// Creates a TaskManager with the test environment
    func createTaskManager(
        processor: VideoProcessorProtocol? = nil,
        maxConcurrentTasks: Int = 3
    ) throws -> TaskManagerProtocol {
        let downloader = createDownloader()
        let parser = try container.resolve(M3U8ParserServiceProtocol.self)
        let proc: VideoProcessorProtocol
        if let processor = processor {
            proc = processor
        } else {
            proc = try container.resolve(VideoProcessorProtocol.self)
        }
        let logger = try container.resolve(LoggerProtocol.self)
        let networkClient = mockNetworkClient as NetworkClientProtocol
        
        return DefaultTaskManager(
            downloader: downloader,
            parser: parser,
            processor: proc,
            fileSystem: fileSystem,
            configuration: configuration,
            maxConcurrentTasks: maxConcurrentTasks,
            networkClient: networkClient,
            logger: logger
        )
    }
}

