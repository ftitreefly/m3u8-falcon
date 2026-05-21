# Linux Support Guide

<!-- markdownlint-disable-next-line MD033 -->
<img src="../Logo-512px.png" alt="M3U8Falcon logo" width="200">

Complete guide for using M3U8Falcon on Linux platforms.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Platform-Specific Features](#platform-specific-features)
4. [Architecture](#architecture)
5. [Platform Differences](#platform-differences)
6. [Building and Testing](#building-and-testing)
7. [Troubleshooting](#troubleshooting)
8. [Performance Considerations](#performance-considerations)

## Overview

M3U8Falcon provides full Linux support with platform-specific optimizations. The library automatically detects the platform and uses the appropriate implementations for process execution, network streaming, and file system operations.

### Supported Linux Distributions

- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Fedora 34+
- ✅ RHEL 8+
- ✅ Arch Linux
- ✅ Other distributions with Swift 6.0+ support

### Requirements

- **Swift**: 6.0 or later
- **FFmpeg**: Required for video processing
- **System Libraries**: Standard Linux system libraries (libc, libpthread, etc.)

## Installation

### Step 1: Install Swift

```bash
# Ubuntu/Debian
wget -q https://swift.org/builds/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0-RELEASE-ubuntu22.04 /opt/swift
export PATH=/opt/swift/usr/bin:$PATH

# Fedora/RHEL
sudo dnf install swift-lang

# Arch Linux
yay -S swift-bin
```

### Step 2: Install FFmpeg

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg

# Fedora/RHEL
sudo dnf install ffmpeg

# Arch Linux
sudo pacman -S ffmpeg
```

### Step 3: Add to Your Project

Add M3U8Falcon to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ftitreefly/m3u8-falcon.git", from: "1.2.0")
]
```

### Step 4: Verify Installation

```bash
# Clone the repository
git clone https://github.com/ftitreefly/m3u8-falcon.git
cd m3u8-falcon

# Build the project
swift build

# Run tests
swift test

# Test CLI
swift run m3u8-falcon info
```

## Platform-Specific Features

### 1. Process Execution

Linux uses a polling-based approach for process output capture, optimized for Linux's process handling:

```swift
// Linux automatically uses LinuxProcessExecutor
let result = try await processExecutor.execute(
    executable: "/usr/bin/ffmpeg",
    arguments: ["-version"],
    timeout: 10.0
)
```

**Key Features:**
- ✅ Continuous polling with `DispatchGroup` for reliable output capture
- ✅ Thread-safe data accumulation
- ✅ Proper signal handling and cleanup
- ✅ Timeout support with cancellation

### 2. Streaming Downloads

Linux uses `URLSessionDataDelegate` for byte streaming, providing efficient memory usage:

```swift
// Automatically uses LinuxStreamingNetworkClient
let (response, stream) = try await streamingClient.fetchAsyncBytes(from: url)
for try await byte in stream {
    // Process bytes
}
```

**Key Features:**
- ✅ Batch buffering (8KB batches) for performance
- ✅ Memory-efficient streaming
- ✅ Proper error handling and cleanup
- ✅ Thread-safe continuation management

### 3. File System Operations

Linux follows XDG Base Directory specification:

```swift
// Downloads directory resolution
// macOS: ~/Downloads
// Linux: XDG_DOWNLOAD_DIR or ~/Downloads
let downloadsDir = FileManager.default.urls(
    for: .downloadsDirectory,
    in: .userDomainMask
).first!
```

**XDG Compliance:**
- ✅ Respects `XDG_DOWNLOAD_DIR` environment variable
- ✅ Falls back to `~/.config/user-dirs.dirs`
- ✅ Defaults to `~/Downloads` if XDG not configured

### 4. Thread Safety

Linux uses `NSLock` and `DispatchGroup` for thread-safe operations:

```swift
// Platform-aware concurrency
private let lock = NSLock()
private let group = DispatchGroup()

lock.lock()
defer { lock.unlock() }
// Thread-safe operations
```

## Building and Testing

### Build Commands

```bash
# Debug build
swift build

# Release build
swift build -c release

# Build with verbose output
swift build -v

# Clean build
swift package clean
swift build
```

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test suite
swift test --filter ParseTests

# Run tests in parallel
swift test --parallel
```

### CLI Usage

```bash
# Build CLI
swift build -c release

# Run CLI directly
swift run m3u8-falcon https://example.com/video.m3u8

# Install CLI (optional)
sudo cp .build/release/m3u8-falcon /usr/local/bin/
```

## Troubleshooting

### Common Issues

#### 1. FFmpeg Not Found

**Problem:** `FFmpeg not found in PATH`

**Solution:**
```bash
# Verify FFmpeg installation
which ffmpeg
ffmpeg -version

# If not found, install FFmpeg
sudo apt install ffmpeg  # Ubuntu/Debian
sudo dnf install ffmpeg  # Fedora/RHEL

# Or specify custom path
export PATH=$PATH:/custom/path/to/ffmpeg
```

#### 2. Swift Version Issues

**Problem:** `Swift version 6.0 or later is required`

**Solution:**
```bash
# Check Swift version
swift --version

# Update Swift (see Installation section)
# Or use Swift toolchain manager
```

#### 3. Permission Denied

**Problem:** Cannot write to download directory

**Solution:**
```bash
# Check directory permissions
ls -ld ~/Downloads

# Fix permissions if needed
chmod 755 ~/Downloads

# Or use custom directory
export XDG_DOWNLOAD_DIR=/path/to/downloads
```

#### 4. Network Timeout

**Problem:** Downloads timeout on Linux

**Solution:**
```swift
// Increase timeout in configuration
let config = DIConfiguration(
    downloadTimeout: 120.0  // 2 minutes
)
await M3U8Falcon.initialize(with: config)
```

#### 5. Process Execution Hangs

**Problem:** Process executor hangs on Linux

**Solution:**
- Ensure proper timeout is set
- Check if process is actually running: `ps aux | grep ffmpeg`
- Verify process has proper permissions
- Check system resources (memory, CPU)

### Debug Mode

Enable verbose logging for troubleshooting:

```swift
// Enable debug logging
Logger.configure(.development())

// Or custom configuration
let config = LoggerConfiguration(
    minimumLevel: .debug,
    includeTimestamps: true,
    enableColors: true
)
Logger.configure(config)
```

## Performance Considerations

### Optimization Tips

1. **Batch Size**: Linux streaming uses 8KB batches for optimal performance
2. **Polling Interval**: Process executor uses 10ms polling interval
3. **Concurrent Downloads**: Limit to 10-15 concurrent tasks on Linux for best performance
4. **Memory Management**: Streaming downloads are memory-efficient with batch buffering

### Benchmarking

```bash
# Build release version
swift build -c release

# Run performance tests
swift test --filter PerformanceOptimizedTests
```

### Resource Usage

- **Memory**: ~50-100MB base, +10-20MB per concurrent download
- **CPU**: Minimal when idle, scales with concurrent downloads
- **Network**: Limited by system network stack and bandwidth

## Additional Resources

- [Main README](../README.md) - Project overview
- [User Guide](USER_GUIDE.md) - Complete usage guide
- [Developer Guide](DEVELOPER_GUIDE.md) - Extension and contribution guide
- [Project Overview](PROJECT_OVERVIEW.md) - Architecture details

## Support

- **GitHub Issues**: [Report Linux-specific issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **GitHub Discussions**: [Ask questions](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

**Last Updated**: 2026-05-22
**M3U8Falcon Version**: 1.3.2+

