//
//  DownloadCommand.swift
//  M3U8FalconCLI
//
//  Created by tree_fly on 2025/7/13.
//

import ArgumentParser
import Foundation
import M3U8Falcon

/// Command for downloading M3U8 video files from URLs
/// 
/// This command downloads M3U8 playlist files and all their associated video segments
/// to the user's Downloads directory. It supports both HTTP and HTTPS URLs.
/// 
/// ## Usage Examples
/// ```bash
/// # Download with default settings
/// m3u8-falcon download https://example.com/video.m3u8
/// 
/// # Download with custom filename
/// m3u8-falcon download https://example.com/video.m3u8 --name my-video
/// 
/// # Download to custom directory
/// m3u8-falcon download https://example.com/video.m3u8 --output /path/to/videos
/// 
/// # Download with verbose output
/// m3u8-falcon download https://example.com/video.m3u8 -v
/// 
/// # Download encrypted content with custom decryption key
/// m3u8-falcon download https://example.com/video.m3u8 --key 0123456789abcdef0123456789abcdef
/// 
/// # Download encrypted content with both key and IV
/// m3u8-falcon download https://example.com/video.m3u8 --key 0123456789abcdef0123456789abcdef --iv 0123456789abcdef0123456789abcdef
/// ```
/// 
/// ## Output
/// Downloaded files will be saved to the user's Downloads directory by default,
/// or to a custom directory if specified with the `--output` option.
struct DownloadCommand: AsyncParsableCommand {
    /// Command configuration including name and description
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download M3U8 Video Files",
        discussion: """
        Download M3U8 playlist files and all their associated video segments.
        
        Supported features:
        - Automatically download all video segments in the playlist
        - Support for HTTP and HTTPS URLs
        - Customizable output filename and directory
        - Detailed download progress information
        - Error handling and retry mechanisms
        - Support for encrypted M3U8 files with custom AES-128 decryption (key and IV)
        
        Downloaded files will be saved to the user's Downloads directory by default,
        or to a custom directory if specified with the --output option.
        """,
        version: CLI.version
    )
    
    /// The URL of the M3U8 file to download
    /// 
    /// This must be a valid HTTP or HTTPS URL pointing to an M3U8 playlist file.
    /// The URL should be accessible and the file should be a valid M3U8 format.
    @Argument(help: "URL of the M3U8 file")
    var url: String

    /// Optional custom name for the output file
    /// 
    /// If provided, this name will be used for the downloaded M3U8 file.
    /// If not provided, the original filename from the URL will be used.
    /// 
    /// Example: `--name my-video` will save the file as `my-video.mp4`
    @Option(name: [.short, .long], help: "Output filename (saved as .mp4)")
    var name: String?
    
    /// Optional custom directory to save downloaded files
    /// 
    /// If provided, files will be saved to this directory instead of the default Downloads folder.
    /// The directory will be created if it doesn't exist.
    /// 
    /// Example: `--output /path/to/videos` will save files to `/path/to/videos`
    @Option(name: [.short, .long], help: "Output directory for downloaded files (defaults to Downloads folder)")
    var output: String?

    /// Enable verbose output for detailed download information
    /// 
    /// When enabled, provides detailed information about the download process,
    /// including progress updates, file sizes, and timing information.
    @Flag(name: [.short, .long], help: "Show verbose output")
    var verbose: Bool = false
    
    /// Custom AES-128 decryption key (hex string)
    /// 
    /// When provided, this key will be used to decrypt encrypted video segments,
    /// overriding any KEY URL specified in the M3U8 playlist.
    /// 
    /// Example: `--key 0123456789abcdef0123456789abcdef`
    @Option(name: [.customLong("key")], help: "Custom AES-128 decryption key (16-byte KEY, in hex string)")
    var key: String?
    
    /// Custom AES-128 initialization vector (hex string)
    /// 
    /// When provided, this IV will be used along with the decryption KEY,
    /// overriding any IV specified in the M3U8 playlist.
    /// 
    /// Example: `--iv 0123456789abcdef0123456789abcdef`
    @Option(name: [.customLong("iv")], help: "Custom AES-128 initialization vector (16-byte IV, in hex string)")
    var iv: String?
    
    /// Executes the download command
    /// 
    /// This method performs the following steps:
    /// 1. Initializes the dependency injection container
    /// 2. Validates the provided URL
    /// 3. Downloads the M3U8 file and all associated segments
    /// 4. Saves files to the specified output directory (or Downloads directory by default)
    /// 5. Provides status updates and error handling
    /// 
    /// - Throws: 
    ///   - `ExitCode.failure` if URL is invalid or download fails
    ///   - Various network and file system errors during download
    mutating func run() async throws {
        await M3U8Falcon.initialize(verbose: verbose)
        
        try await validateFFmpegAvailability()
            
        guard let downloadURL = URL(string: url) else {
            OutputFormatter.printError("Invalid URL format")
            throw ExitCode.failure
        }
        if let scheme = downloadURL.scheme?.lowercased(), scheme != "http" && scheme != "https" {
            OutputFormatter.printError("Unsupported URL scheme: \(scheme). Only http/https are supported.")
            throw ExitCode.failure
        }
     
        do {
            if verbose { 
                OutputFormatter.printInfo("Starting m3u8 file download...")
                if key != nil {
                    OutputFormatter.printInfo("Using custom decryption key")
                }
                if iv != nil {
                    OutputFormatter.printInfo("Using custom initialization vector")
                }
            }
            
            // Build decryption strategy if key is provided
            let strategy: DecryptionStrategy?
            if let key = key {
                strategy = .customAES128(key: key, iv: iv)
            } else {
                strategy = nil
            }
            
            // Resolve output directory
            let outputDirectory: URL?
            if let outputPath = output {
                outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)
            } else {
                outputDirectory = nil // Uses default Downloads directory
            }
            
            try await M3U8Falcon.download(
                .web,
                url: downloadURL,
                savedDirectory: outputDirectory,
                name: name,
                strategy: strategy,
                verbose: verbose
            )
            if verbose { 
                OutputFormatter.printSuccess("Download completed!")
                await printPerformanceMetrics()
            }
        } catch {
            if let tfErr = error as? (any M3U8FalconError) {
                let suggestion = tfErr.recoverySuggestion ?? ""
                var errorMessage = "Download failed [\(tfErr.code)]: \(tfErr.localizedDescription)"
                
                // Include underlying error details if available
                if let underlying = tfErr.underlyingError {
                    errorMessage += " | Cause: \(underlying.localizedDescription)"
                }
                
                if !suggestion.isEmpty {
                    errorMessage += " | Suggestion: \(suggestion)"
                }
                
                OutputFormatter.printError(errorMessage)
            } else {
                OutputFormatter.printError("Download failed: \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - Output Helpers

struct OutputFormatter {
    static func printSuccess(_ message: String) {
        print("✅ \(message)")
    }
    
    static func printError(_ message: String) {
        print("❌ \(message)")
    }
    
    static func printInfo(_ message: String) {
        print("ℹ️  \(message)")
    }
    
    static func printWarning(_ message: String) {
        print("⚠️  \(message)")
    }
    
    /// Prints formatted performance metrics
    static func printPerformanceMetrics(_ metrics: PerformanceMetrics) {
        print("")
        print("📊 Performance Metrics:")
        print("  • Completed Tasks: \(metrics.completedTasks)")
        print("  • Active Tasks: \(metrics.activeTasks)")
        
        if metrics.completedTasks > 0 {
            print("  • Average Download Time: \(String(format: "%.2f", metrics.averageDownloadTime))s")
            print("  • Average Processing Time: \(String(format: "%.2f", metrics.averageProcessingTime))s")
            print("  • Cumulative Task Time: \(String(format: "%.2f", metrics.cumulativeTaskTime))s")
        } else {
            print("  • No completed tasks yet")
        }
        print("")
    }
}

// MARK: - Private Helpers

private extension DownloadCommand {
    /// Ensures FFmpeg is available before starting downloads
    func validateFFmpegAvailability() async throws {
        let configuration = try await GlobalDependencies.shared.resolve(DIConfiguration.self)
        guard let ffmpegPath = configuration.ffmpegPath else {
            OutputFormatter.printError("FFmpeg executable not found. Please install FFmpeg (https://ffmpeg.org/download.html) or provide a DI configuration with a valid ffmpegPath.")
            throw ExitCode.failure
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: ffmpegPath), fileManager.isExecutableFile(atPath: ffmpegPath) else {
            OutputFormatter.printError("FFmpeg executable is not accessible at \(ffmpegPath). Verify the path or install FFmpeg.")
            throw ExitCode.failure
        }
    }

    /// Prints performance metrics if available
    func printPerformanceMetrics() async {
        do {
            let taskManager = try await GlobalDependencies.shared.resolve(TaskManagerProtocol.self)
            
            // Check if it's DefaultTaskManager to access getPerformanceMetrics
            if let defaultTaskManager = taskManager as? DefaultTaskManager {
                let metrics = await defaultTaskManager.getPerformanceMetrics()
                OutputFormatter.printPerformanceMetrics(metrics)
            }
        } catch {
            // Silently fail if metrics are not available
        }
    }
}
