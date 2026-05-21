# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.2] - 2026-05-21

### Added
- **Centralized Versioning System**: Standardized release versioning with `/VERSION` as the single source of truth, supported by automation scripts (`generate-version.sh` and `generation+commit-version.sh`) that sync variables into CLI targets.
- **Decryption Key Upfront Validation**: Added hexadecimal structure validation (exact 32-character, 16-byte length checks) on input `--key` and `--iv` parameters in the download command before executing downloads.

### Changed
- **Unified Dependency Injection**: Standardized DI resolution logic across commands using `GlobalDependencies.shared.resolve` under a unified dependency model.
- **Type-Safe Option Transforms**: Configured custom enums parsing natively using `ExpressibleByArgument` with `@Option(transform:)` mappings inside extraction sub-commands.
- **Dot-Delimited Host Matching**: Enforced dot-delimited sub-domain validations (`host == domain || host.hasSuffix("." + domain)`) in the YouTube crawler extractor to avoid suffix-bypass vulnerabilities.

### Fixed
- **Objective-C Collision Prevention**: Fixed symbol type conflicts between custom CLI commands and Foundation's `objc_method` pointers.
- **Tilde Path Expansion**: Resolved path resolving issues in dynamic local downloads to successfully handle file scheme descriptors and expand local folders prefixed by `~`.

## [1.3.1] - 2026-05-06

### Added
- **URL Pipeline Support**: Enhanced download command to consume M3U8 video stream URLs directly from `stdin` when executed in non-TTY (piped) shell sessions.

## [1.3.0] - 2025-11-28

### Added
- **Decryption Strategy Integration**: Introduced the dynamic `DecryptionStrategy` enum configuration enabling robust custom AES-128 key and IV decryption parameters.
- **File System Support**: Enhanced directories and path checking helper implementations inside the file systems layer.

## [1.2.5] - 2026-05-21

### Added
- **Key Check Integration**: Expanded parameter checks to ensure secure download executions.
- **Local File Scheme Check**: Integrated compatibility layers for local file systems references inside core download tasks.

## [1.2.4] - 2026-05-06

### Added
- **Local Playlists Support**: Enabled formatting and parser supports for parsing customized local M3U8 playlist configurations.
- **Command Output Metrics**: Introduced the `CommandExecutionResult` output metrics schema to record process results in detail.

## [1.2.3] - 2025-12-26

### Fixed
- **Code Optimization**: Fixed compiler warnings and adjusted default values in testing environments to improve performance test speeds.

## [1.2.2] - 2025-11-19

### Added
- **Network Pipeline**: Integrated retry workflows, exponential backoffs, and concurrent connection pooling interfaces inside the core parser workflows.

## [1.2.1] - 2025-11-19

### Added
- **Constants Definition**: Defined custom processing parameters under a unified constants schema.

## [1.2.0] - 2025-11-17

### Added
- **Linux Concurrency Strategy**: Authored custom multi-threading implementations utilizing standard locking strategies (`NSLock`) and thread safe dispatch systems rather than raw atomic wrappers.
- **Platform-Agnostic Streams**: Completed custom `URLSessionDataDelegate` adapters and platform-specific background processes to fully support Linux CLI download executions.
- **Dynamic Path Discoveries**: Enhanced path resolution routines and integrated environment variable searches for external binaries like FFmpeg.

## [1.1.0] - 2025-11-17

### Added
- **Swift Testing Framework Integration**: Migrated test targets from XCTest to the modern Swift Testing suite.
- **Detailed Error Logging**: Enhanced CLI error logs with actionable repair advice and metrics reporting.

## [1.0.1] - 2025-11-14

### Fixed
- **Linux Compatibility**: Removed unused Foundation CryptoKit module imports to facilitate seamless compilation on Linux setups.

## [1.0.0] - 2025-11-13

### Added
- **Initial Release**: Core Swift 6 library & CLI engine for downloading, parsing, and combining M3U8 video segments using FFmpeg, equipped with dual-language document sets.

[Unreleased]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/ftitreefly/m3u8-falcon/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/ftitreefly/m3u8-falcon/releases/tag/v1.0.0

