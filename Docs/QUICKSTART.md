# Quick Start Guide

Get started with M3U8Falcon in 5 minutes!

## Prerequisites

Before you begin, ensure you have:

- **macOS 12.0 or later**
- **Swift 6.0 or later**
- **FFmpeg** installed (required for video processing)

### Installing FFmpeg

```bash
# Using Homebrew (recommended)
brew install ffmpeg

# Verify installation
ffmpeg -version
```

## Installation

### Option 1: Swift Package Manager (Recommended)

Add M3U8Falcon to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "M3U8Falcon", package: "m3u8-falcon")
    ]
)
```

### Option 2: Xcode

1. In Xcode, go to **File** → **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/ftitreefly/m3u8-falcon.git`
3. Select the version (1.0.0 or later)
4. Add `M3U8Falcon` to your target

## Basic Usage

### As a Library

#### Step 1: Import the Module

```swift
import M3U8Falcon
```

#### Step 2: Initialize

```swift
// Initialize with default configuration
await M3U8Falcon.initialize()
```

#### Step 3: Download a Video

```swift
// Download from M3U8 URL
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video",
    verbose: true
)

print("✅ Video downloaded successfully!")
```

### As a CLI Tool

#### Building the CLI

```bash
# Clone the repository
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# Build the CLI
swift build -c release

# The executable will be at: .build/release/m3u8-falcon
```

#### Basic CLI Commands

```bash
# Download a video
m3u8-falcon download https://example.com/video.m3u8

# Download with custom filename
m3u8-falcon download https://example.com/video.m3u8 --name my-video

# Download with verbose output
m3u8-falcon download https://example.com/video.m3u8 -v

# Extract M3U8 links from a web page
m3u8-falcon extract "https://example.com/video-page"

# Show tool information
m3u8-falcon info
```

## Common Use Cases

### 1. Download a Simple Video

```swift
import M3U8Falcon

await M3U8Falcon.initialize()

try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "my-video"
)
```

### 2. Download with Progress Tracking

```swift
try await M3U8Falcon.download(
    .web,
    url: videoURL,
    savedDirectory: outputDir,
    name: "my-video",
    verbose: true  // Enable verbose output for progress
)
```

### 3. Download Encrypted Video

```swift
try await M3U8Falcon.download(
    .web,
    url: URL(string: "https://example.com/encrypted-video.m3u8")!,
    savedDirectory: URL(fileURLWithPath: "~/Downloads/"),
    name: "encrypted-video",
    customKey: "0123456789abcdef0123456789abcdef",
    customIV: "0123456789abcdef0123456789abcdef"
)
```

### 4. Parse M3U8 File

```swift
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

## Configuration

### Custom Configuration

```swift
let customConfig = DIConfiguration(
    ffmpegPath: "/custom/path/ffmpeg",
    maxConcurrentDownloads: 10,
    downloadTimeout: 60
)

await M3U8Falcon.initialize(with: customConfig)
```

### Logging Configuration

```swift
// Production mode (minimal output)
Logger.configure(.production())

// Development mode (detailed output)
Logger.configure(.development())
```

## Error Handling

```swift
do {
    try await M3U8Falcon.download(.web, url: videoURL, verbose: true)
} catch let error as FileSystemError {
    print("File system error: \(error.message)")
} catch let error as NetworkError {
    print("Network error: \(error.message)")
} catch let error as ParsingError {
    print("Parsing error: \(error.message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

Now that you've got the basics working:

1. **Read the [User Guide](USER_GUIDE.md)** for detailed usage instructions
2. **Check the [API Reference](API_REFERENCE.md)** for complete API documentation
3. **Explore [Advanced Features](../README.md#-advanced-usage)** for more capabilities
4. **See [Developer Guide](DEVELOPER_GUIDE.md)** if you want to extend the library

## Troubleshooting

### Common Issues

#### FFmpeg Not Found

**Error**: `FFmpeg not found at path: /usr/local/bin/ffmpeg`

**Solution**: 
```bash
# Install FFmpeg
brew install ffmpeg

# Or specify custom path in configuration
let config = DIConfiguration(ffmpegPath: "/your/custom/path/ffmpeg")
await M3U8Falcon.initialize(with: config)
```

#### Network Timeout

**Error**: Network timeout errors

**Solution**: Increase timeout in configuration:
```swift
let config = DIConfiguration(downloadTimeout: 120) // 120 seconds
await M3U8Falcon.initialize(with: config)
```

#### Invalid URL

**Error**: Invalid URL errors

**Solution**: Ensure URLs use `http://` or `https://` scheme:
```swift
// ✅ Correct
URL(string: "https://example.com/video.m3u8")

// ❌ Incorrect
URL(string: "example.com/video.m3u8")
```

## Getting Help

- **Documentation**: See other guides in the `Docs/` directory
- **Issues**: [GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

Happy downloading! 🚀

