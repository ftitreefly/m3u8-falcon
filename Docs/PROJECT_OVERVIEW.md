# M3U8Falcon - Project Overview

## Introduction

M3U8Falcon is a high-performance Swift library and command-line tool designed for downloading, parsing, and processing M3U8 video files. Built with Swift 6+ features, modern concurrency patterns, and a comprehensive dependency injection architecture, it provides a robust solution for handling HTTP Live Streaming (HLS) content.

## What is M3U8?

M3U8 is a text-based playlist format used for HTTP Live Streaming (HLS). It contains references to media segments that make up a video stream. M3U8 files are commonly used by video streaming services to deliver adaptive bitrate streaming content.

## Project Goals

### Primary Objectives

1. **High Performance**: Efficiently download and process M3U8 video streams with minimal resource usage
2. **Reliability**: Robust error handling and retry mechanisms for network operations
3. **Extensibility**: Protocol-based architecture allowing easy integration of custom extractors and processors
4. **Developer Experience**: Clean API design with comprehensive documentation and examples
5. **Production Ready**: Extensive testing, proper error handling, and logging capabilities

### Key Features

- **Swift 6+ Ready**: Leverages the latest Swift concurrency features with strict concurrency checking
- **Dependency Injection**: Full DI architecture for better testability and modularity
- **Cross-Platform**: macOS 12.0+ support with both library and CLI interfaces
- **Comprehensive Error Handling**: Detailed error types with context information
- **Concurrent Downloads**: Configurable concurrent download support (up to 20 concurrent tasks)
- **Advanced Logging System**: Multi-level logging with categories and colored output
- **Multiple Sources**: Support for both web URLs and local M3U8 files
- **Video Processing**: FFmpeg integration for video segment combination
- **Encryption Support**: Built-in support for encrypted M3U8 streams with custom key/IV override
- **Extensible Architecture**: Protocol-based design for easy third-party integrations

## Architecture Overview

### Core Components

#### 1. Dependency Injection System
- **Location**: `Sources/M3U8Falcon/Core/DependencyInjection/`
- **Purpose**: Manages service registration and resolution
- **Key Files**:
  - `DependencyContainer.swift`: Main DI container
  - `DIConfiguration.swift`: Configuration management

#### 2. M3U8 Parser
- **Location**: `Sources/M3U8Falcon/Core/Parsers/M3U8Parser/`
- **Purpose**: Parses M3U8 playlist files (both master and media playlists)
- **Key Features**:
  - Master playlist parsing
  - Media playlist parsing
  - Tag-based parsing system

#### 3. Download Services
- **Location**: `Sources/M3U8Falcon/Services/Default/`
- **Purpose**: Handles downloading of M3U8 files and video segments
- **Key Components**:
  - `DefaultM3U8Downloader.swift`: Main download orchestrator
  - `StreamingDownloader.swift`: Streaming download support
  - `DefaultTaskManager.swift`: Concurrent task management

#### 4. Network Layer
- **Location**: `Sources/M3U8Falcon/Services/Network/`
- **Purpose**: Network communication with retry strategies
- **Key Features**:
  - Enhanced network client with retry logic
  - Configurable retry strategies
  - Timeout handling

#### 5. Video Processing
- **Location**: `Sources/M3U8Falcon/Services/Default/DefaultVideoProcessor.swift`
- **Purpose**: Combines video segments using FFmpeg
- **Features**:
  - Segment merging
  - Encryption handling
  - Format conversion support

#### 6. Link Extraction
- **Location**: `Sources/M3U8Falcon/Services/Default/`
- **Purpose**: Extracts M3U8 links from web pages
- **Key Components**:
  - `DefaultM3U8LinkExtractor.swift`: Base extractor
  - `DefaultM3U8ExtractorRegistry.swift`: Extractor registry
  - Protocol-based design for custom extractors

#### 7. CLI Interface
- **Location**: `Sources/M3U8FalconCLI/`
- **Purpose**: Command-line interface for end users
- **Commands**:
  - `download`: Download M3U8 videos
  - `extract`: Extract M3U8 links from web pages
  - `info`: Show tool information

### Design Patterns

#### Dependency Injection
All services are registered through a dependency injection container, allowing for:
- Easy testing with mock services
- Flexible configuration
- Loose coupling between components

#### Protocol-Oriented Programming
Core functionality is defined through protocols:
- `M3U8LinkExtractorProtocol`: For custom link extractors
- `ServiceProtocols.swift`: Core service protocols
- Enables easy extension and customization

#### Modern Swift Concurrency
- Uses `async/await` for asynchronous operations
- `Task` and `TaskGroup` for concurrent operations
- Strict concurrency checking enabled

## Technology Stack

### Core Technologies
- **Swift 6.0+**: Modern Swift with strict concurrency
- **Foundation**: Core system frameworks
- **Swift Argument Parser**: CLI argument parsing

### External Dependencies
- **FFmpeg**: Video processing and segment merging (system dependency)

### Development Tools
- **Swift Package Manager**: Dependency management
- **XCTest**: Testing framework

## Project Structure

```
M3U8Falcon/
├── Sources/
│   ├── M3U8Falcon/          # Core library
│   │   ├── Core/            # Core components
│   │   ├── Services/        # Service implementations
│   │   └── Utilities/       # Utility functions
│   └── M3U8FalconCLI/       # CLI tool
├── Tests/                   # Test suites
├── Docs/                    # Documentation
└── Package.swift            # Package configuration
```

## Use Cases

### 1. Video Download
Download complete videos from M3U8 playlists for offline viewing.

### 2. Link Extraction
Extract M3U8 links from video hosting websites automatically.

### 3. Playlist Analysis
Parse and analyze M3U8 playlist structures for debugging or analysis.

### 4. Custom Integration
Integrate M3U8 downloading capabilities into your own applications.

## Target Audience

### End Users
- Users who want to download videos from M3U8 streams
- Users who need offline access to streaming content
- Users who prefer command-line tools

### Developers
- Swift developers building video-related applications
- Developers needing M3U8 parsing capabilities
- Developers creating custom video extractors

## Performance Characteristics

- **Concurrent Downloads**: Up to 20 concurrent segment downloads
- **Memory Efficient**: Streaming downloads with minimal memory footprint
- **Network Optimized**: Retry strategies and timeout handling
- **Resource Management**: Automatic cleanup of temporary files

## Security Considerations

- **Encryption Support**: AES-128 decryption for encrypted streams
- **Custom Keys**: Support for custom decryption keys and IVs
- **Secure Downloads**: HTTPS support for secure connections
- **Input Validation**: Comprehensive validation of URLs and file paths

## Future Roadmap

Potential future enhancements:
- Additional platform support (Linux, Windows)
- More video format support
- Enhanced extractor ecosystem
- GUI application
- Advanced video processing options

## Contributing

We welcome contributions! Please see the [Contributing Guide](CONTRIBUTING.md) for details on:
- Code style guidelines
- Testing requirements
- Pull request process
- Issue reporting

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Support

- **Documentation**: See other guides in the `Docs/` directory
- **Issues**: [GitHub Issues](https://github.com/ftitreefly/m3u8-falcon/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ftitreefly/m3u8-falcon/discussions)

---

Made with ❤️ by the M3U8Falcon Team

