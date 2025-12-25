# M3U8Falcon

<!-- markdownlint-disable-next-line MD033 -->
<img src="Logo-512px.png" alt="M3U8Falcon logo" width="300">

[![GitHub Release](https://img.shields.io/github/v/release/ftitreefly/m3u8-falcon?color=8A2BE2)](https://github.com/ftitreefly/m3u8-falcon/releases)
[![min macOS](https://img.shields.io/badge/macOS-12.0+-silver)](#)
[![Linux](https://img.shields.io/badge/Linux-supported-success)](#)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange)](#)
[![License](https://img.shields.io/badge/License-MIT-blue)](#)

[中文文档](README_zh.md) | English

A high-performance Swift library and CLI tool for downloading, parsing, and processing M3U8 video files. Built with Swift 6+ features, modern concurrency patterns, and comprehensive dependency injection architecture.

## ✨ Features

- 🚀 **Swift 6+**: Modern concurrency patterns and dependency injection architecture
- 📱 **Cross-Platform**: macOS 12.0+ and Linux support (library & CLI)
- 🔄 **High Performance**: Concurrent downloads (up to 20 tasks) with streaming support
- 🎬 **Video Processing**: FFmpeg integration with automatic retry logic for network operations
- 🔐 **Encryption**: Built-in AES-128 decryption with custom key/IV support
- 🔌 **Extensible**: Protocol-based design for custom extractors and integrations
- 🛡️ **Production Ready**: Comprehensive error handling, logging, and test coverage

## 🚀 Quick Start - Get Started in 5 Minutes

### Installation

#### macOS

```bash
# 1. Install FFmpeg (required for video processing)
brew install ffmpeg

# 2. Add to your Package.swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

#### Linux

```bash
# 1. Install FFmpeg (required for video processing)
# Ubuntu/Debian
sudo apt update && sudo apt install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg

# 2. Add to your Package.swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

### Basic Usage Example

```swift
import M3U8Falcon

// ⚠️ IMPORTANT: Initialize the library first (required)
await M3U8Falcon.initialize()

// Download a video from M3U8 URL
// savedDirectory is optional - defaults to Downloads folder
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    name: "my-video"
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

## 🐧 Linux Support

M3U8Falcon fully supports Linux with platform-specific optimizations:

### Platform-Specific Features

- ✅ **Process Execution**: Optimized polling-based output capture for Linux
- ✅ **Streaming Downloads**: Custom byte streaming implementation using URLSessionDataDelegate
- ✅ **Thread Safety**: Platform-aware concurrency management with NSLock and DispatchGroup
- ✅ **Path Resolution**: XDG Base Directory specification support for user directories
- ✅ **FFmpeg Integration**: Automatic FFmpeg path detection across common Linux installations

### Platform Differences

The library automatically handles platform differences:

| Feature | macOS/iOS | Linux |
|---------|-----------|-------|
| Process Output Capture | `readabilityHandler` | Polling with `DispatchGroup` |
| Streaming Downloads | `URLSession.bytes` | `URLSessionDataDelegate` |
| Terminal Detection | `Darwin.isatty` | `Glibc.isatty` |
| URL Cache | `directory` parameter | `diskPath` parameter |
| Downloads Directory | `~/Downloads` | XDG_DOWNLOAD_DIR / `~/.config/user-dirs.dirs` |

### Building on Linux

```bash
# Clone and build
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon
swift build

# Run tests
swift test

# Run CLI
swift run m3u8-falcon download https://example.com/video.m3u8 -v
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

// Download an M3U8 file (savedDirectory is optional, defaults to Downloads folder)
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    name: "my-video"
)

// Download with custom directory
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "my-video"
)

// Download encrypted M3U8 with custom AES-128 decryption
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// Download encrypted M3U8 with key only (IV derived from segment sequence)
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
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

### Extract M3U8 Links from Web Pages

```swift
import M3U8Falcon

// Initialize the library first
await M3U8Falcon.initialize()

// Create extractor registry (uses configuration from DI container)
let registry = await DefaultM3U8ExtractorRegistry.create()

// Or create with default configuration (one line)
// let registry = DefaultM3U8ExtractorRegistry()

// Register custom extractors (optional)
// registry.registerExtractor(YouTubeExtractor())
// registry.registerExtractor(VimeoExtractor())

// Extract M3U8 links from a web page
let links = try await registry.extractM3U8Links(
    from: URL(string: "https://example.com/video-page")!,
    options: LinkExtractionOptions.default
)

for link in links {
    print("Found M3U8 link: \(link.url) (confidence: \(link.confidence))")
}
```

### CLI Commands

```bash
# Download an M3U8 file with default settings
m3u8-falcon download https://example.com/video.m3u8

# Download with custom filename
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# Download to custom directory
m3u8-falcon download https://example.com/video.m3u8 --output /path/to/videos

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
// Configure with verbose logging
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 30,
    logLevel: .verbose 
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

For encrypted M3U8 streams, you can provide custom AES-128 decryption using the `DecryptionStrategy` enum:

```swift
// No decryption (default)
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    name: "video"
)

// Custom AES-128 decryption with key and IV
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// Custom AES-128 decryption with key only (IV derived from segment sequence)
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
)
```

**Key Format**: Hexadecimal string (32 characters for 128-bit AES)

- Example: `"0123456789abcdef0123456789abcdef"`
- Whitespace and `0x` prefix are automatically stripped
- IV is optional - if not provided, it will be derived from the segment sequence number

### Error Handling

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, name: "my-video")
} catch let error as FileSystemError {
    print("File system error: \(error.message)")
} catch let error as NetworkError {
    print("Network error: \(error.message)")
} catch let error as ConfigurationError {
    print("Configuration error: \(error.message)")
    // Make sure to call M3U8Falcon.initialize() first
} catch {
    print("Unexpected error: \(error)")
}
```

---

## 🧪 Testing & Development

M3U8Falcon uses Swift Testing framework for comprehensive test coverage.

### Run Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test suite
swift test --filter ParseTests
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
