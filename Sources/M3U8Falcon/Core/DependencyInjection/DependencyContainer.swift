//
//  DependencyContainer.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Dependency Container

/// Thread-safe dependency injection container for M3U8 utility services
/// 
/// This container provides a thread-safe way to register and resolve dependencies
/// for the M3U8 utility library. It supports both transient and singleton service
/// registration with automatic dependency resolution.
/// 
/// ## Features
/// - Thread-safe service registration and resolution
/// - Support for both transient and singleton services
/// - Automatic dependency resolution
/// - Performance-optimized service configuration
/// - Global shared instance for convenience
/// 
/// ## Usage Example
/// ```swift
/// // Create a new container
/// let container = DependencyContainer()
/// 
/// // Configure with performance-optimized services
/// container.configurePerformanceOptimized()
/// 
/// // Resolve services
/// let downloader = container.resolve(M3U8DownloaderProtocol.self)
/// let parser = container.resolve(M3U8ParserServiceProtocol.self)
/// 
/// // Use the global shared instance
/// let taskManager = Dependencies.resolve(TaskManagerProtocol.self)
/// ```
public final class DependencyContainer: Sendable {
    
    /// Thread-safe storage for registered services
    private let storage: Storage
    
    /// Initializes a new dependency container
    /// 
    /// Creates a fresh container instance with thread-safe storage.
    public init() {
        self.storage = Storage()
    }
    
    /// Registers a transient service with the container
    /// 
    /// Transient services are created fresh each time they are resolved.
    /// This is useful for services that should not maintain state between uses.
    /// 
    /// - Parameters:
    ///   - type: The protocol type to register
    ///   - factory: A closure that creates the service instance
    /// 
    /// ## Usage Example
    /// ```swift
    /// container.register(M3U8DownloaderProtocol.self) {
    ///     DefaultM3U8Downloader(
    ///         commandExecutor: commandExecutor,
    ///         configuration: configuration
    ///     )
    /// }
    /// ```
    public func register<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        storage.register(type, factory: factory)
    }
    
    /// Registers a singleton service with the container
    /// 
    /// Singleton services are created once and reused for all subsequent resolutions.
    /// This is useful for services that maintain state or are expensive to create.
    /// 
    /// - Parameters:
    ///   - type: The protocol type to register
    ///   - factory: A closure that creates the service instance
    /// 
    /// ## Usage Example
    /// ```swift
    /// container.registerSingleton(FileSystemServiceProtocol.self) {
    ///     DefaultFileSystemService()
    /// }
    /// ```
    public func registerSingleton<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        storage.registerSingleton(type, factory: factory)
    }
    
    /// Resolves a service from the container
    /// 
    /// This method creates or retrieves a service instance based on its registration.
    /// For transient services, a new instance is created each time. For singletons,
    /// the same instance is returned.
    /// 
    /// - Parameter type: The protocol type to resolve
    /// 
    /// - Returns: An instance of the requested service
    /// 
    /// - Throws: `ConfigurationError` if the service is not registered or cast fails
    /// 
    /// ## Usage Example
    /// ```swift
    /// let downloader = try container.resolve(M3U8DownloaderProtocol.self)
    /// let content = try await downloader.downloadContent(from: url)
    /// ```
    public func resolve<T>(_ type: T.Type) throws -> T {
        return try storage.tryResolve(type)
    }
    
    /// Resolves a service and throws typed configuration errors instead of terminating the process
    ///
    /// - Parameter type: The protocol type to resolve
    /// - Returns: The resolved instance
    /// - Throws: `ConfigurationError` when service is not registered or cast fails
    public func tryResolve<T>(_ type: T.Type) throws -> T {
        return try storage.tryResolve(type)
    }
    
    /// Configures the container with the specified configuration
    /// 
    /// This method registers all the default services used by the M3U8 utility
    /// with the provided configuration. It sets up the complete dependency graph
    /// for the library.
    /// 
    /// - Parameter configuration: Configuration settings for the services
    /// - Note: This method also configures the global `Logger` based on the DI settings.
    /// 
    /// ## Usage Example
    /// ```swift
    /// let container = DependencyContainer()
    /// let config = DIConfiguration.performanceOptimized()
    /// container.configure(with: config)
    /// 
    /// // Now all services are available
    /// let taskManager = container.resolve(TaskManagerProtocol.self)
    /// ```
    public func configure(with configuration: DIConfiguration) {
        // Configure global logger according to DI settings
        Logger.configure(
            LoggerConfiguration(
                minimumLevel: configuration.logLevel,
                includeTimestamps: false,
                includeCategories: true,
                includeEmoji: true,
                enableColors: true
            )
        )
        registerSingleton(DIConfiguration.self) { configuration }
        registerSingleton(FileSystemServiceProtocol.self) { DefaultFileSystemService() }
        registerSingleton(PathProviderProtocol.self) { DefaultFileSystemService() }
        registerSingleton(CommandExecutorProtocol.self) { DefaultCommandExecutor() }
        
        // Platform-specific abstractions
        registerSingleton(ProcessExecutorProtocol.self) {
            #if canImport(Darwin)
            return DarwinProcessExecutor()
            #else
            return LinuxProcessExecutor()
            #endif
        }
        
        registerSingleton(StreamingNetworkClientProtocol.self) {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.downloadTimeout
            sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
            
            #if canImport(Darwin)
            return DarwinStreamingNetworkClient(session: URLSession(configuration: sessionConfig))
            #else
            return LinuxStreamingNetworkClient(configuration: sessionConfig)
            #endif
        }
        
        registerSingleton(NetworkClientProtocol.self) {
            EnhancedNetworkClient(
                configuration: configuration,
                retryStrategy: ExponentialBackoffRetryStrategy(
                    baseDelay: configuration.retryBackoffBase,
                    maxAttempts: configuration.retryAttempts
                ),
                monitor: nil // Can be configured later for monitoring
            )
        }
        registerSingleton(LoggerProtocol.self) { LoggerAdapter() }
        
        register(M3U8DownloaderProtocol.self) { [weak self] in
            guard let self = self else {
                fatalError("Container deallocated during service creation")
            }
            
            guard let commandExecutor = try? self.resolve(CommandExecutorProtocol.self),
                  let configuration = try? self.resolve(DIConfiguration.self),
                  let net = try? self.resolve(NetworkClientProtocol.self) else {
                fatalError("Failed to resolve required dependencies for M3U8DownloaderProtocol. Ensure all services are properly configured.")
            }
            
            return DefaultM3U8Downloader(
                commandExecutor: commandExecutor,
                configuration: configuration,
                networkClient: net
            )
        }
        
        register(M3U8ParserServiceProtocol.self) { DefaultM3U8ParserService() }
        
        register(VideoProcessorProtocol.self) { [weak self] in
            guard let self = self else {
                fatalError("Container deallocated during service creation")
            }
            
            guard let commandExecutor = try? self.resolve(CommandExecutorProtocol.self),
                  let configuration = try? self.resolve(DIConfiguration.self) else {
                fatalError("Failed to resolve required dependencies for VideoProcessorProtocol. Ensure all services are properly configured.")
            }
            
            return DefaultVideoProcessor(
                commandExecutor: commandExecutor,
                configuration: configuration
            )
        }
        
        // Provide extractor registry with injected logger and network client
        register(M3U8ExtractorRegistryProtocol.self) {
            let net = DefaultNetworkClient(configuration: configuration)
            return DefaultM3U8ExtractorRegistry(
                defaultExtractor: DefaultM3U8LinkExtractor(networkClient: net)
            )
        }
        
        register(TaskManagerProtocol.self) { [weak self] in
            guard let self = self else {
                fatalError("Container deallocated during service creation")
            }
            
            guard let downloader = try? self.resolve(M3U8DownloaderProtocol.self),
                  let parser = try? self.resolve(M3U8ParserServiceProtocol.self),
                  let processor = try? self.resolve(VideoProcessorProtocol.self),
                  let fileSystem = try? self.resolve(FileSystemServiceProtocol.self),
                  let configuration = try? self.resolve(DIConfiguration.self),
                  let networkClient = try? self.resolve(NetworkClientProtocol.self) else {
                fatalError("Failed to resolve required dependencies for TaskManagerProtocol. Ensure all services are properly configured.")
            }
            
            return DefaultTaskManager(
                downloader: downloader,
                parser: parser,
                processor: processor,
                fileSystem: fileSystem,
                configuration: configuration,
                maxConcurrentTasks: configuration.maxConcurrentDownloads / 4,
                networkClient: networkClient,
                logger: LoggerAdapter()
            )
        }
    }

    /// Clears all registrations and singletons. Use with caution.
    public func reset() {
        storage.reset()
    }
}

// MARK: - Thread-Safe Storage

/// Thread-safe storage for registered services
/// 
/// This private class provides thread-safe storage for service factories and
/// singleton instances. It uses recursive locks to ensure thread safety.
private final class Storage: @unchecked Sendable {
    /// Lock for thread-safe access to storage
    private let lock = NSRecursiveLock()
    
    /// Registered service factories (keyed by ObjectIdentifier)
    private var factories: [ObjectIdentifier: () -> Any] = [:]
    
    /// Cached singleton instances
    private var singletons: [ObjectIdentifier: Any] = [:]
    
    /// Registers a transient service factory
    /// 
    /// - Parameters:
    ///   - type: The service type to register
    ///   - factory: Factory closure that creates the service
    func register<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
    }
    
    /// Registers a singleton service factory
    /// 
    /// - Parameters:
    ///   - type: The service type to register
    ///   - factory: Factory closure that creates the service
    func registerSingleton<T>(_ type: T.Type, factory: @escaping @Sendable () -> T) {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = { [weak self] in
            guard let self else { return factory() }
            if let existing = self.singletons[key] as? T {
                return existing
            }
            let instance = factory()
            self.singletons[key] = instance
            return instance
        }
    }
    
    /// Resolves a service instance
    /// 
    /// - Parameter type: The service type to resolve
    /// 
    /// - Returns: An instance of the requested service
    /// 
    /// - Throws: Fatal error if service is not registered or cast fails
    func resolve<T>(_ type: T.Type) -> T {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        
        guard let factory = factories[key] else {
            fatalError("Service \(type) not registered. Call configureDefaults() or register the service manually.")
        }
        
        guard let instance = factory() as? T else {
            fatalError("Failed to cast service to expected type \(type)")
        }
        
        return instance
    }
    
    /// Throwing variant that returns typed configuration errors instead of terminating the process
    func tryResolve<T>(_ type: T.Type) throws -> T {
        let key = ObjectIdentifier(type)
        lock.lock()
        defer { lock.unlock() }
        
        guard let factory = factories[key] else {
            throw ConfigurationError.missingParameter("Service: \(type)")
        }
        
        guard let instance = factory() as? T else {
            throw ConfigurationError.invalidParameterValue("Service: \(type)", value: "Type cast failed")
        }
        
        return instance
    }
    
    /// Remove all registrations and singletons
    func reset() {
        lock.lock()
        factories.removeAll(keepingCapacity: false)
        singletons.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}

// MARK: - Convenience Extensions

public extension DependencyContainer {
    /// Convenience method for resolving services
    /// 
    /// This is a shorthand for the `resolve` method, providing a more
    /// concise syntax for service resolution.
    /// 
    /// - Parameter type: The service type to resolve
    /// 
    /// - Returns: An instance of the requested service
    /// 
    /// ## Usage Example
    /// ```swift
    /// let downloader = container.get(M3U8DownloaderProtocol.self)
    /// ```
    func get<T>(_ type: T.Type) throws -> T {
        return try resolve(type)
    }
}

// MARK: - Global DI (Actor-isolated)

/// Global, actor-isolated access to dependency injection container
public actor GlobalDependencies {
    public static let shared = GlobalDependencies()
    private var container: DependencyContainer = DependencyContainer()
    
    public func configure(with configuration: DIConfiguration) {
        container.configure(with: configuration)
    }
    
    public func resolve<T>(_ type: T.Type) throws -> T {
        try container.resolve(type)
    }
    
    public func reset() {
        container.reset()
    }
    
    /// Replace the underlying container for testing
    public func replaceShared(forTesting newContainer: DependencyContainer) {
        container = newContainer
    }
}
