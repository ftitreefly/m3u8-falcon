# Developer Guide

Complete guide for developers who want to extend or contribute to M3U8Falcon.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Architecture Overview](#architecture-overview)
3. [Creating Custom Extractors](#creating-custom-extractors)
4. [Extending Services](#extending-services)
5. [Testing](#testing)
6. [Contributing](#contributing)
7. [Code Style](#code-style)

## Project Structure

```
M3U8Falcon/
├── Sources/
│   ├── M3U8Falcon/              # Core library
│   │   ├── Core/
│   │   │   ├── DependencyInjection/  # DI system
│   │   │   ├── Parsers/              # M3U8 parsing
│   │   │   ├── Protocols/            # Protocol definitions
│   │   │   └── Types/                # Type definitions
│   │   ├── Services/
│   │   │   ├── Default/              # Default implementations
│   │   │   ├── Network/              # Network layer
│   │   │   └── Streaming/            # Streaming support
│   │   ├── Utilities/
│   │   │   ├── Errors/               # Error types
│   │   │   ├── Extensions/           # Swift extensions
│   │   │   ├── Logging/              # Logging system
│   │   │   └── ResourceManagement/   # Resource cleanup
│   │   └── M3U8Falcon.swift          # Public API
│   └── M3U8FalconCLI/            # CLI tool
│       ├── Commands/              # CLI commands
│       └── Extractors/            # CLI-specific extractors
├── Tests/                        # Test suites
└── Docs/                         # Documentation
```

## Architecture Overview

### Dependency Injection

M3U8Falcon uses a dependency injection system for better testability and modularity.

#### Core Components

- **DependencyContainer**: Manages service registration and resolution
- **DIConfiguration**: Configuration for services
- **GlobalDependencies**: Singleton container instance

#### Registering Services

```swift
// Services are registered in DependencyContainer
let container = DependencyContainer()
container.register(NetworkClientProtocol.self) { _ in
    EnhancedNetworkClient()
}
```

### Protocol-Oriented Design

The library uses protocols extensively for extensibility:

- **M3U8LinkExtractorProtocol**: For custom link extractors
- **ServiceProtocols**: Core service protocols
- All services are protocol-based for easy mocking in tests

## Creating Custom Extractors

### Overview

Extractors are used to extract M3U8 links from web pages. You can create custom extractors for specific video hosting sites.

### Implementation Steps

#### 1. Implement the Protocol

```swift
import Foundation
import M3U8Falcon

final class MyCustomExtractor: M3U8LinkExtractorProtocol {
    
    private let supportedDomains = ["example.com", "video.example.com"]
    
    public init() {}
    
    // Core extraction method
    public func extractM3U8Links(
        from url: URL,
        options: LinkExtractionOptions
    ) async throws -> [M3U8Link] {
        // 1. Download the web page
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // 2. Parse HTML to find M3U8 links
        var links: [M3U8Link] = []
        
        // Your custom parsing logic here
        // Example: Use regex, HTML parser, or JavaScript execution
        
        // 3. Return found links
        return links
    }
    
    // Return supported domains
    public func getSupportedDomains() -> [String] {
        return supportedDomains
    }
    
    // Return extractor information
    public func getExtractorInfo() -> ExtractorInfo {
        return ExtractorInfo(
            name: "My Custom Extractor",
            version: "1.0.0",
            supportedDomains: getSupportedDomains(),
            capabilities: [.directLinks, .javascriptVariables]
        )
    }
    
    // Check if this extractor can handle the URL
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return supportedDomains.contains { host.hasSuffix($0) }
    }
}
```

#### 2. Register the Extractor

```swift
// In your application initialization
let registry = DefaultM3U8ExtractorRegistry()
let customExtractor = MyCustomExtractor()
registry.registerExtractor(customExtractor)
```

#### 3. Use the Extractor

```swift
let url = URL(string: "https://example.com/video-page")!
let links = try await registry.extractM3U8Links(
    from: url,
    options: LinkExtractionOptions.default
)
```

### Best Practices for Extractors

1. **Error Handling**: Always handle errors gracefully
2. **Timeout**: Respect the timeout in `LinkExtractionOptions`
3. **Retries**: Use the retry mechanism from options
4. **Validation**: Validate extracted URLs before returning
5. **Performance**: Cache parsed results when possible

### Example: YouTube Extractor

See `Sources/M3U8FalconCLI/Extractors/YouTubeExtractor.swift` for a complete example.

## Extending Services

### Creating Custom Services

You can extend M3U8Falcon by implementing custom service protocols.

#### Example: Custom Network Client

```swift
import Foundation
import M3U8Falcon

final class CustomNetworkClient: NetworkClientProtocol {
    
    func download(
        from url: URL,
        timeout: TimeInterval
    ) async throws -> Data {
        // Your custom network implementation
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
    
    func download(
        from url: URL,
        to destination: URL,
        timeout: TimeInterval
    ) async throws {
        // Your custom download implementation
        let (localURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: localURL, to: destination)
    }
}
```

#### Registering Custom Services

```swift
// Create custom configuration
var config = DIConfiguration.performanceOptimized()

// Register custom service (if supported by DI system)
// Note: This may require modifying the DI container

await M3U8Falcon.initialize(with: config)
```

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter NetworkLayerTests
```

### Writing Tests

#### Test Structure

```swift
import XCTest
@testable import M3U8Falcon

final class MyExtractorTests: XCTestCase {
    
    var extractor: MyCustomExtractor!
    
    override func setUp() {
        super.setUp()
        extractor = MyCustomExtractor()
    }
    
    override func tearDown() {
        extractor = nil
        super.tearDown()
    }
    
    func testExtraction() async throws {
        let url = URL(string: "https://example.com/video")!
        let links = try await extractor.extractM3U8Links(
            from: url,
            options: .default
        )
        
        XCTAssertFalse(links.isEmpty)
    }
}
```

#### Mocking Services

```swift
// Create mock service
final class MockNetworkClient: NetworkClientProtocol {
    var downloadData: Data?
    var downloadError: Error?
    
    func download(from url: URL, timeout: TimeInterval) async throws -> Data {
        if let error = downloadError {
            throw error
        }
        return downloadData ?? Data()
    }
    
    func download(from url: URL, to destination: URL, timeout: TimeInterval) async throws {
        // Mock implementation
    }
}
```

### Test Coverage

Aim for high test coverage:
- Unit tests for individual components
- Integration tests for workflows
- Performance tests for critical paths

## Contributing

### Getting Started

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/my-feature`
3. **Make your changes**
4. **Write tests** for your changes
5. **Run tests**: `swift test`
6. **Commit your changes**: `git commit -am 'Add my feature'`
7. **Push to the branch**: `git push origin feature/my-feature`
8. **Create a Pull Request**

### Pull Request Guidelines

1. **Clear Description**: Describe what and why
2. **Tests**: Include tests for new features
3. **Documentation**: Update documentation if needed
4. **Code Style**: Follow the project's code style
5. **Small PRs**: Keep pull requests focused and small

### Issue Reporting

When reporting issues, include:
- Swift version
- macOS version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Error messages/logs

## Code Style

### Swift Style Guide

Follow Swift API Design Guidelines and these conventions:

#### Naming

```swift
// ✅ Good
func downloadVideo(from url: URL) async throws

// ❌ Bad
func dl(url: URL) async throws
```

#### Error Handling

```swift
// ✅ Good - Specific error types
throw NetworkError.timeout(url: url)

// ❌ Bad - Generic errors
throw NSError(domain: "error", code: 1)
```

#### Concurrency

```swift
// ✅ Good - Use async/await
func download() async throws -> Data

// ❌ Bad - Callbacks
func download(completion: @escaping (Result<Data, Error>) -> Void)
```

#### Documentation

```swift
/// Downloads M3U8 content from a URL
///
/// - Parameters:
///   - url: The URL to download from
///   - timeout: Request timeout in seconds
/// - Returns: The downloaded data
/// - Throws: NetworkError if download fails
func download(from url: URL, timeout: TimeInterval) async throws -> Data
```

### File Organization

- One type per file (when possible)
- Group related types in folders
- Use MARK comments for organization

```swift
// MARK: - Public API

// MARK: - Private Helpers
```

## Advanced Topics

### Memory Management

- Use weak references for delegates
- Clean up resources in `deinit`
- Use `TaskGroup` for concurrent operations

### Performance Optimization

- Use concurrent downloads appropriately
- Cache parsed results
- Minimize memory allocations
- Profile with Instruments

### Error Handling Strategy

- Use specific error types
- Provide context in errors
- Log errors appropriately
- Don't swallow errors silently

## Resources

- [Swift Documentation](https://swift.org/documentation/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Package Manager](https://swift.org/package-manager/)
- [Project Overview](PROJECT_OVERVIEW.md)
- [API Reference](API_REFERENCE.md)

## Getting Help

- **GitHub Issues**: [Report bugs or ask questions](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**: [Discuss ideas](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **Code Review**: Submit PRs for code review

---

Happy coding! 💻

