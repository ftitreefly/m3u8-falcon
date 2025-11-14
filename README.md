# M3U8Falcon

<!-- markdownlint-disable-next-line MD033 -->
<img src="Logo-512px.png" alt="M3U8Falcon logo" width="300">

[中文文档](README_zh.md) | English

A high-performance Swift library and CLI tool for downloading, parsing, and processing M3U8 video files. Built with Swift 6+ features, modern concurrency patterns, and comprehensive dependency injection architecture.

## ✨ Features

- 🚀 **Swift 6+ Ready**: Built with the latest Swift 6 features including strict concurrency checking
- 🔧 **Dependency Injection**: Full DI architecture for better testability and modularity
- 📱 **Cross-Platform**: macOS 12.0+ support with both library and CLI interfaces
- 🛡️ **Comprehensive Error Handling**: Detailed error types with context information
- 🔄 **Concurrent Downloads**: Configurable concurrent download support (up to 20 concurrent tasks)
- 📊 **Advanced Logging System**: Multi-level logging with categories and colored output
- 🎯 **Multiple Sources**: Support for both web URLs and local M3U8 files
- 🎬 **Video Processing**: FFmpeg integration for video segment combination
- 🔐 **Encryption Support**: Built-in support for encrypted M3U8 streams with custom key/IV override
- 🔌 **Extensible Architecture**: Protocol-based design for easy third-party integrations
- 🧪 **Extensive Testing**: Comprehensive test suites covering all major functionality

## 🚀 Quick Start - Get Started in 5 Minutes

### Installation

```bash
# 1. Install FFmpeg (required for video processing)
brew install ffmpeg

# 2. Add to your Package.swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

### Basic Usage Example

```swift
import M3U8Falcon

// Initialize the library
await M3U8Falcon.initialize()

// Download a video from M3U8 URL
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video",
    verbose: true
)

print("✅ Video downloaded successfully!")
```

### CLI Tool - One Command to Download

```bash
# Download M3U8 video with a single command
m3u8-falcon download https://example.com/video.m3u8

# Download with custom filename and verbose output
m3u8-falcon download https://example.com/video.m3u8 --name my-video -v

# Extract M3U8 links from web pages
m3u8-falcon extract "https://example.com/video-page"
```

That's it! For more advanced features, see the sections below.

---

## 🔌 M3U8LinkExtractorProtocol - Core Integration Interface

`M3U8LinkExtractorProtocol` is the core extensibility interface of M3U8Falcon, enabling third-party developers to easily integrate M3U8 link extraction functionality for various video websites.

### Protocol Overview

```swift
public protocol M3U8LinkExtractorProtocol: Sendable {
    /// Extract M3U8 links from a web page
    func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link]
    
    /// Return the list of domains supported by this extractor
    func getSupportedDomains() -> [String]
    
    /// Return complete information about this extractor
    func getExtractorInfo() -> ExtractorInfo
    
    /// Check if this extractor can handle the specified URL
    func canHandle(url: URL) -> Bool
}
```

### Complete Working Example

Here's a complete, runnable example showing how to implement a custom M3U8 extractor:

```swift
import Foundation
import M3U8Falcon

// 1️⃣ Create a custom extractor
final class CustomVideoSiteExtractor: M3U8LinkExtractorProtocol {
    
    private let supportedDomains = ["example.com", "video.example.com"]
    
    public init() {}
    
    // Core method for extracting M3U8 links
    public func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
        // Download web page content
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Custom extract function
        var links: [M3U8Link] = []
        for index in 0 ... 5 {
            let m3u8URL = "video-\(index).m3u8"
            let videoName = "name-\(index)"
            
            links.append(M3U8Link(
                url: m3u8URL,
                name: videoName
            ))
        }
        
        return links
    }
    
    // Return supported domains
    public func getSupportedDomains() -> [String] {
        return supportedDomains
    }
    
    // Return extractor information
    public func getExtractorInfo() -> ExtractorInfo {
        return ExtractorInfo(
            name: "Custom Video Site Extractor",
            version: "1.0.0",
            supportedDomains: getSupportedDomains(),
            capabilities: [.directLinks, .javascriptVariables]
        )
    }
    
    // Check if this URL can be handled
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return supportedDomains.contains { host.hasSuffix($0) }
    }
}

// 2️⃣ Register and use the extractor
async func main() async throws {
    // Create extractor registry
    let registry = DefaultM3U8ExtractorRegistry()
    
    // Register your custom extractor
    let customExtractor = CustomVideoSiteExtractor()
    registry.registerExtractor(customExtractor)
    
    // Use the extractor to extract M3U8 links
    let url = URL(string: "https://example.com/video-page")!
    let links = try await registry.extractM3U8Links(
        from: url,
        options: LinkExtractionOptions.default
    )
    
    // Process extracted links
    print("Found \(links.count) M3U8 links:")
    for link in links {
        print("  📹 \(link.name)")
        print("     URL: \(link.url)")
    }
    
    // 3️⃣ Download the first extracted video
    if let firstLink = links.first {
        await M3U8Falcon.initialize()
        try await M3U8Falcon.download(
            .web,
            url: firstLink.url,
            savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
            name: firstLink.name,
            verbose: true
        )
        print("✅ Video downloaded successfully!")
    }
}

// Run the example
try await main()
```

### Key Components

#### M3U8Link Structure

```swift
public struct M3U8Link: Sendable {
    let url: URL              // M3U8 playlist URL (required)
    let name: String          // Video name (required)
    let quality: Quality      // Video quality - optional metadata
    // Additional optional fields: bandwidth, resolution, source, etc.
}
```

#### LinkExtractionOptions

```swift
public struct LinkExtractionOptions: Sendable {
    let timeout: TimeInterval        // Request timeout
    let maxRetries: Int              // Maximum retry attempts
    let methods: [ExtractionMethod]  // Extraction methods
    let headers: [String: String]    // HTTP headers
    
    public static let `default`: LinkExtractionOptions
}
```

#### ExtractorInfo

```swift
public struct ExtractorInfo: Sendable {
    let name: String                    // Extractor name
    let version: String                 // Version number
    let supportedDomains: [String]      // Supported domain list
    let capabilities: [Capability]      // Capability list
}
```

### CLI Integration

Your custom extractor can also be used via CLI:

```bash
# Extract M3U8 links
m3u8-falcon extract "https://example.com/video-page"

# View registered extractors
m3u8-falcon extract "https://example.com/video-page" --show-extractors

# Specify extraction method
m3u8-falcon extract "https://example.com/video-page" --methods direct-links
```

---

## 📚 Documentation

- **[Project Overview](Docs/PROJECT_OVERVIEW.md)** - Architecture and technical stack
- **[Quick Start Guide](Docs/QUICKSTART.md)** - Get started in 5 minutes
- **[User Guide](Docs/USER_GUIDE.md)** - Complete feature documentation and usage examples
- **[Developer Guide](Docs/DEVELOPER_GUIDE.md)** - Architecture, development workflow, and contribution guide
- **[Documentation Index](Docs/README.md)** - Central hub for all documentation

---

## 📖 Advanced Usage

### Download Videos

```swift
import M3U8Falcon

// Initialize the utility
await M3U8Falcon.initialize()

// Download an M3U8 file with verbose output
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "my-video",
    verbose: true
)

// Download encrypted M3U8 with custom decryption key and IV
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)
```

### Parse M3U8 Files

```swift
// Parse an M3U8 file
let result = try await M3U8Falcon.parse(
    url: URL(string: "https://example.com/video.m3u8")!
)

switch result {
case .master(let masterPlaylist):
    print("Master playlist with \(masterPlaylist.tags.streamTags.count) streams")
case .media(let mediaPlaylist):
    print("Media playlist with \(mediaPlaylist.tags.mediaSegments.count) segments")
case .cancelled:
    print("Parsing was cancelled")
}
```

### CLI Commands

```bash
# Download an M3U8 file with default settings
m3u8-falcon download https://example.com/video.m3u8

# Download with custom filename
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# Download encrypted M3U8 with custom decryption key
m3u8-falcon download https://example.com/video.m3u8 --key 0123456789abcdef0123456789abcdef

# Download with both custom key and IV
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef \
  --iv 0123456789abcdef0123456789abcdef \
  --name my-video \
  -v

# Show tool information
m3u8-falcon info
```

Note: CLI URLs must use http or https schemes.

---

## 🔧 Configuration & Advanced Features

### Custom Configuration

```swift
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 60,
    key: "0123456789abcdef0123456789abcdef",  // Optional: default decryption key
    iv: "0123456789abcdef0123456789abcdef"     // Optional: default IV
)

await M3U8Falcon.initialize(with: customConfig)
```

### Logging System

```swift
// Production configuration - minimal output
Logger.configure(.production())

// Development configuration - detailed output
Logger.configure(.development())

// Custom configuration
let customConfig = LoggerConfiguration(
    minimumLevel: .debug,
    includeTimestamps: true,
    includeCategories: true,
    enableColors: true
)
Logger.configure(customConfig)
```

### Encrypted M3U8 Support

For encrypted M3U8 streams, you can provide custom AES-128 decryption keys:

```swift
// Method 1: Via configuration (applies to all downloads)
let config = DIConfiguration(
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
await M3U8Falcon.initialize(with: config)

// Method 2: Per-download override (takes precedence over configuration)
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    savedDirectory: outputDir,
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
```

**Key Format**: Hexadecimal string (32 characters for 128-bit AES)

- Example: `"0123456789abcdef0123456789abcdef"`
- Whitespace and `0x` prefix are automatically stripped

### Error Handling

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    print("File system error: \(error.message)")
} catch let error as NetworkError {
    print("Network error: \(error.message)")
} catch {
    print("Unexpected error: \(error)")
}
```

---

## 🧪 Testing & Development

### Run Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter NetworkLayerTests
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# Build the project
swift build

# Run tests
swift test

# Build and run CLI
swift run m3u8-falcon --help

# Test download with verbose output
swift run m3u8-falcon download https://example.com/video.m3u8 -v
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Notices

This project includes code adapted from [go-swifty-m3u8](https://github.com/gal-orlanczyk/go-swifty-m3u8), which is licensed under the MIT License:

```text
Copyright (c) Gal Orlanczyk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

---

## 🆘 Support & Resources

- **📖 Full Documentation**: [Documentation Index](Docs/README.md)
- **🐛 Issues**: [GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **👥 Developer Guide**: [Developer Documentation](Docs/DEVELOPER_GUIDE.md)
- **📝 Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

## 🌟 Star History

If you find this project helpful, please consider giving it a star ⭐️ on GitHub!

---

Made with ❤️ by the M3U8Falcon Team
