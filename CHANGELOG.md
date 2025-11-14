# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2025-11-14

### Fixed
- Removed unused `CryptoKit` imports to enable Linux builds
- Fixed build error: `no such module 'CryptoKit'` on Linux platforms

## [1.0.0] - 2025-11-13

### Added
**Core Features**
- Swift 6+ with strict concurrency checking and dependency injection architecture
- High-performance M3U8 downloading/parsing with up to 20 concurrent tasks
- FFmpeg integration for video segment combination
- Encrypted M3U8 support with custom key/IV override
- Both Swift library and CLI tool interfaces

**Network & Performance**
- Enhanced network client with retry logic and exponential backoff
- Connection pooling, HTTP/2 support, and performance metrics
- Actor-based concurrency for thread safety
- Memory-efficient streaming downloads with progress tracking

**Developer Experience**
- Multi-level logging system with categories and colored output
- Comprehensive error handling with recovery suggestions
- Protocol-based design for extensibility
- M3U8LinkExtractorProtocol for third-party integrations (includes YouTube extractor)

**CLI Commands**
- `m3u8-falcon download` - Download M3U8 videos
- `m3u8-falcon extract` - Extract M3U8 links from web pages
- `m3u8-falcon info` - Display tool information

**Documentation & Testing**
- Complete bilingual documentation (English + Chinese): Quick Start, User Guide, Developer Guide
- Comprehensive test suites: integration, network, parser, performance, memory management

**Requirements**
- macOS 12.0+, Swift 6.0+, FFmpeg (for video processing)
- Dependencies: swift-argument-parser 1.0.0+

[Unreleased]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/ftitreefly/m3u8-falcon/releases/tag/v1.0.1
[1.0.0]: https://github.com/ftitreefly/m3u8-falcon/releases/tag/v1.0.0

