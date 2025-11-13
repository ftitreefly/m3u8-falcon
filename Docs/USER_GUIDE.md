# User Guide

Complete guide to using M3U8Falcon for downloading and processing M3U8 videos.

## Table of Contents

1. [Installation](#installation)
2. [Basic Usage](#basic-usage)
3. [CLI Commands](#cli-commands)
4. [Advanced Features](#advanced-features)
5. [Configuration](#configuration)
6. [Error Handling](#error-handling)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Installation

### System Requirements

- macOS 12.0 or later
- Swift 6.0 or later
- FFmpeg (for video processing)

### Installing FFmpeg

```bash
# Using Homebrew
brew install ffmpeg

# Verify installation
ffmpeg -version
```

### Installing M3U8Falcon

See the [Quick Start Guide](QUICKSTART.md) for detailed installation instructions.

## Basic Usage

### Library Usage

#### Initialization

```swift
import M3U8Falcon

// Initialize with default settings
await M3U8Falcon.initialize()

// Or with custom configuration
let config = DIConfiguration(
    maxConcurrentDownloads: 10,
    downloadTimeout: 60
)
await M3U8Falcon.initialize(with: config)
```

#### Downloading Videos

```swift
// Basic download
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video"
)

// Download with verbose output
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "my-video",
    verbose: true
)
```

#### Parsing M3U8 Files

```swift
let result = try await M3U8Falcon.parse(
    url: URL(string: "https://example.com/video.m3u8")!
)

switch result {
case .master(let masterPlaylist):
    // Handle master playlist
    for stream in masterPlaylist.tags.streamTags {
        print("Stream: \(stream.uri)")
    }
case .media(let mediaPlaylist):
    // Handle media playlist
    print("Segments: \(mediaPlaylist.tags.mediaSegments.count)")
case .cancelled:
    print("Parsing cancelled")
}
```

## CLI Commands

### Download Command

Download M3U8 videos from URLs.

```bash
# Basic download
m3u8-falcon download https://example.com/video.m3u8

# With custom filename
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# With verbose output
m3u8-falcon download https://example.com/video.m3u8 -v

# Download encrypted video with custom key
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef

# Download with custom key and IV
m3u8-falcon download https://example.com/video.m3u8 \
  --key 0123456789abcdef0123456789abcdef \
  --iv 0123456789abcdef0123456789abcdef \
  --name my-video \
  -v
```

**Options:**
- `--name <name>`: Custom filename for the output video
- `--key <key>`: Custom AES-128 decryption key (hex string)
- `--iv <iv>`: Custom initialization vector (hex string)
- `-v, --verbose`: Enable verbose output

### Extract Command

Extract M3U8 links from web pages.

```bash
# Extract links from a web page
m3u8-falcon extract "https://example.com/video-page"

# Show registered extractors
m3u8-falcon extract "https://example.com/video-page" --show-extractors

# Specify extraction methods
m3u8-falcon extract "https://example.com/video-page" --methods direct-links
```

**Options:**
- `--show-extractors`: Display all registered extractors
- `--methods <methods>`: Specify extraction methods (comma-separated)

### Info Command

Display tool information.

```bash
m3u8-falcon info
```

## Advanced Features

### Encrypted Streams

M3U8Falcon supports AES-128 encrypted streams with custom keys.

#### Using Custom Decryption Keys

```swift
// Method 1: Per-download key
try await M3U8Falcon.download(
    .web,
    url: encryptedVideoURL,
    savedDirectory: outputDir,
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)

// Method 2: Global configuration
let config = DIConfiguration(
    key: "0123456789abcdef0123456789abcdef",
    iv: "0123456789abcdef0123456789abcdef"
)
await M3U8Falcon.initialize(with: config)
```

**Key Format:**
- Hexadecimal string (32 characters for 128-bit AES)
- Example: `"0123456789abcdef0123456789abcdef"`
- Whitespace and `0x` prefix are automatically stripped

### Concurrent Downloads

Configure the number of concurrent segment downloads:

```swift
let config = DIConfiguration(
    maxConcurrentDownloads: 20  // Maximum: 20
)
await M3U8Falcon.initialize(with: config)
```

**Recommendations:**
- Default: 5 concurrent downloads
- For fast connections: 10-15
- Maximum: 20 (to avoid overwhelming servers)

### Logging

Configure logging levels and output:

```swift
// Production mode (minimal output)
Logger.configure(.production())

// Development mode (detailed output)
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

**Log Levels:**
- `.error`: Only errors
- `.warning`: Errors and warnings
- `.info`: Errors, warnings, and info messages
- `.debug`: All messages including debug information

### Link Extraction

Extract M3U8 links from web pages using the extractor system:

```swift
import M3U8Falcon

// Create extractor registry
let registry = DefaultM3U8ExtractorRegistry()

// Extract links
let url = URL(string: "https://example.com/video-page")!
let links = try await registry.extractM3U8Links(
    from: url,
    options: LinkExtractionOptions.default
)

// Process extracted links
for link in links {
    print("Found: \(link.name) - \(link.url)")
}
```

## Configuration

### DIConfiguration Options

```swift
let config = DIConfiguration(
    ffmpegPath: "/usr/local/bin/ffmpeg",      // FFmpeg executable path
    maxConcurrentDownloads: 10,                // Max concurrent downloads (1-20)
    downloadTimeout: 60,                       // Download timeout in seconds
    key: nil,                                  // Default decryption key (optional)
    iv: nil                                    // Default IV (optional)
)
```

### Environment Variables

You can also configure some settings via environment variables:

```bash
# Set FFmpeg path
export M3U8_FFMPEG_PATH="/custom/path/ffmpeg"

# Set log level
export M3U8_LOG_LEVEL="debug"
```

## Error Handling

### Error Types

M3U8Falcon provides specific error types for different scenarios:

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    // File system related errors
    print("File system error: \(error.message)")
    print("Path: \(error.path ?? "unknown")")
} catch let error as NetworkError {
    // Network related errors
    print("Network error: \(error.message)")
    print("URL: \(error.url?.absoluteString ?? "unknown")")
} catch let error as ParsingError {
    // M3U8 parsing errors
    print("Parsing error: \(error.message)")
    print("Line: \(error.line ?? "unknown")")
} catch let error as ProcessingError {
    // Video processing errors
    print("Processing error: \(error.message)")
} catch {
    // Other errors
    print("Unexpected error: \(error)")
}
```

### Common Error Scenarios

#### Network Timeout

```swift
// Increase timeout
let config = DIConfiguration(downloadTimeout: 120)
await M3U8Falcon.initialize(with: config)
```

#### FFmpeg Not Found

```swift
// Specify custom FFmpeg path
let config = DIConfiguration(ffmpegPath: "/custom/path/ffmpeg")
await M3U8Falcon.initialize(with: config)
```

#### Invalid M3U8 Format

```swift
// Check if URL is valid M3U8 before downloading
let result = try await M3U8Falcon.parse(url: videoURL)
// If parsing succeeds, proceed with download
```

## Best Practices

### 1. Always Initialize First

```swift
// ✅ Good
await M3U8Falcon.initialize()
try await M3U8Falcon.download(...)

// ❌ Bad
try await M3U8Falcon.download(...)  // May fail without initialization
```

### 2. Use Appropriate Concurrent Downloads

```swift
// ✅ Good - Balanced for most connections
let config = DIConfiguration(maxConcurrentDownloads: 10)

// ❌ Bad - Too many may overwhelm server
let config = DIConfiguration(maxConcurrentDownloads: 50)  // Will be capped at 20
```

### 3. Handle Errors Properly

```swift
// ✅ Good - Specific error handling
do {
    try await M3U8Falcon.download(...)
} catch let error as NetworkError {
    // Handle network errors specifically
} catch {
    // Handle other errors
}

// ❌ Bad - Generic error handling
do {
    try await M3U8Falcon.download(...)
} catch {
    print("Error")  // Not helpful
}
```

### 4. Use Verbose Mode for Debugging

```swift
// Enable verbose output when troubleshooting
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "video",
    verbose: true  // Shows detailed progress
)
```

### 5. Validate URLs Before Downloading

```swift
// ✅ Good - Validate first
guard let url = URL(string: urlString),
      url.scheme == "http" || url.scheme == "https" else {
    print("Invalid URL")
    return
}

// ❌ Bad - May fail with cryptic error
let url = URL(string: urlString)!  // Force unwrap
```

## Troubleshooting

### Download Fails Immediately

**Possible causes:**
- FFmpeg not installed or not in PATH
- Invalid URL format
- Network connectivity issues

**Solutions:**
1. Verify FFmpeg: `ffmpeg -version`
2. Check URL format (must use http:// or https://)
3. Test network connectivity

### Slow Download Speed

**Possible causes:**
- Too few concurrent downloads
- Network bandwidth limitations
- Server rate limiting

**Solutions:**
1. Increase concurrent downloads (up to 20)
2. Check network connection
3. Try downloading at different times

### Video Playback Issues

**Possible causes:**
- Incomplete download
- Missing encryption keys
- Corrupted segments

**Solutions:**
1. Re-download the video
2. Verify encryption keys if applicable
3. Check FFmpeg installation

### Memory Usage High

**Possible causes:**
- Too many concurrent downloads
- Large video files

**Solutions:**
1. Reduce concurrent downloads
2. Process videos in smaller batches
3. Monitor system resources

## Additional Resources

- [Quick Start Guide](QUICKSTART.md) - Get started in 5 minutes
- [Project Overview](PROJECT_OVERVIEW.md) - Architecture and design
- [Developer Guide](DEVELOPER_GUIDE.md) - Extending the library
- [API Reference](API_REFERENCE.md) - Complete API documentation

## Getting Help

- **GitHub Issues**: [Report bugs or request features](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**: [Ask questions or share ideas](https://github.com/ftitreefly/m3u8-falcon/discussions)
- **Documentation**: Check other guides in the `Docs/` directory

---

Happy downloading! 🎬

