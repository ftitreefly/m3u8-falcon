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

do {
    // Download a video from M3U8 URL (savedDirectory is optional, defaults to Downloads folder)
    // The download method (.web or .local) is automatically inferred from the URL scheme!
    try await M3U8Falcon.download(
        url: URL(string: "https://example.com/video.m3u8")!,
        name: "my-video"
    )
    print("✅ Video downloaded successfully!")
} catch {
    print("❌ Download failed: \(error)")
}
```

### CLI Tool - One Command to Download

```bash
# Download M3U8 video with a single command
m3u8-falcon https://example.com/video.m3u8

# Download with custom filename and verbose output
m3u8-falcon https://example.com/video.m3u8 --name my-video -v
```

That's it! For more advanced features, see the sections below.

---

## 🐧 Linux Support

M3U8Falcon fully supports Linux with platform-specific optimizations:

### Building on Linux

```bash
# Clone and build
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon
swift build

# Run tests
swift test

# Run CLI
swift run m3u8-falcon https://example.com/video.m3u8 -v
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
// The download method (.web or .local) is automatically inferred from the URL scheme!
try await M3U8Falcon.download(
    url: URL(string: "https://example.com/video.m3u8")!,
    name: "my-video"
)

// Download with custom directory
try await M3U8Falcon.download(
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "/Users/username/Downloads/videos/"),
    name: "my-video"
)

// Download encrypted M3U8 with custom AES-128 decryption
try await M3U8Falcon.download(
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// Download encrypted M3U8 with key only (IV derived from segment sequence)
try await M3U8Falcon.download(
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
)
```

### CLI Commands

```bash
# Download an M3U8 file with default settings
m3u8-falcon https://example.com/video.m3u8

# Download with custom filename
m3u8-falcon https://example.com/video.m3u8 --name my-video

# Download to custom directory
m3u8-falcon https://example.com/video.m3u8 --output /path/to/videos

# Download encrypted M3U8 with custom decryption key
m3u8-falcon https://example.com/video.m3u8 --key 0123456789abcdef0123456789abcdef

# Download with both custom key and IV
m3u8-falcon https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef \
  --iv 0123456789abcdef0123456789abcdef \
  --name my-video \
  -v

# Download from standard input (pipeline support for non-TTY shells)
echo "https://example.com/video.m3u8" | m3u8-falcon --name piped-video

# Download using local files/paths (supports expanding tilde ~ and absolute file:// URLs)
m3u8-falcon ~/local-playlist.m3u8 --name local-video

```

Note: `download` is the default subcommand, so you can omit it (`m3u8-falcon <url>`). The explicit form `m3u8-falcon download <url>` still works. CLI URLs support http, https, file schemes, and tilde-expanded local paths.

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
```

### Encrypted M3U8 Support

For encrypted M3U8 streams, you can provide custom AES-128 decryption using the `DecryptionStrategy` enum:

```swift
// No decryption (default)
try await M3U8Falcon.download(
    url: videoURL,
    name: "video"
)

// Custom AES-128 decryption with key and IV
try await M3U8Falcon.download(
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(
        key: "0123456789abcdef0123456789abcdef",
        iv: "0123456789abcdef0123456789abcdef"
    )
)

// Custom AES-128 decryption with key only (IV derived from segment sequence)
try await M3U8Falcon.download(
    url: encryptedVideoURL,
    name: "encrypted-video",
    strategy: .customAES128(key: "0123456789abcdef0123456789abcdef")
)
```

**Key Format**: Hexadecimal string (32 characters for 128-bit AES)

- Whitespace and `0x` prefix are automatically stripped
- IV is optional - if not provided, it will be derived from the segment sequence number


---

## 🧪 Testing

M3U8Falcon uses Swift Testing framework for comprehensive test coverage.

### Run Tests

```bash
# Run all tests
swift test
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
