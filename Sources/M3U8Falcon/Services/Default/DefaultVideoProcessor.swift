//
//  DefaultVideoProcessor.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//

import Foundation

// MARK: - Default Video Processor

/// High-performance video processor using Swift 6 features for M3U8 segment processing
/// 
/// This processor provides optimized video processing capabilities for M3U8 video segments,
/// including segment combination, decryption, and format conversion. It uses Swift 6
/// concurrency features and hardware acceleration when available.
/// 
/// Notes:
/// - Requires `DIConfiguration.ffmpegPath` to be set to a valid ffmpeg binary.
/// - The type is a lightweight, thread-safe value type and can be freely passed across tasks.
/// 
/// ## Features
/// - Concurrent segment processing
/// - Hardware acceleration support
/// - Optimized FFmpeg integration
/// - Memory-efficient file operations
/// - Automatic format detection and conversion
/// 
/// ## Usage Example
/// ```swift
/// let processor = DefaultVideoProcessor(
///     commandExecutor: commandExecutor,
///     configuration: configuration,
///     fileSystem: fileSystem
/// )
/// 
/// // Combine segments into a single video file
/// try await processor.combineSegments(
///     in: segmentsDirectory,
///     outputFile: outputVideoURL
/// )
/// 
/// // Decrypt a single segment
/// try await processor.decryptSegment(
///     at: encryptedSegmentURL,
///     to: decryptedSegmentURL,
///     keyURL: decryptionKeyURL
/// )
/// ```
public struct DefaultVideoProcessor: VideoProcessorProtocol {
    /// The command executor for running FFmpeg operations
    private let commandExecutor: CommandExecutorProtocol
    
    /// Configuration settings for video processing
    private let configuration: DIConfiguration
    
    /// File system service for file operations
    private let fileSystem: FileSystemServiceProtocol
    
    /// Initializes a new default video processor
    /// 
    /// - Parameters:
    ///   - commandExecutor: The command executor for running external commands
    ///   - configuration: Configuration settings for video processing
    ///   - fileSystem: File system service for file operations
    public init(commandExecutor: CommandExecutorProtocol, configuration: DIConfiguration, fileSystem: FileSystemServiceProtocol) {
        self.commandExecutor = commandExecutor
        self.configuration = configuration
        self.fileSystem = fileSystem
    }
    
    /// Combines multiple video segments into a single output file
    /// 
    /// This method finds all `.ts` segment files in the specified directory,
    /// creates a concat file for FFmpeg, and combines them into a single video file.
    /// The process is optimized for performance and memory efficiency.
    /// 
    /// Preconditions:
    /// - FFmpeg is available at `configuration.ffmpegPath`
    /// - `directory` contains `.ts` segments in concatenation order (natural sort)
    /// 
    /// - Parameters:
    ///   - directory: The directory containing the video segments
    ///   - outputFile: The URL where the combined video file will be saved
    /// 
    /// - Throws: 
    ///   - `ProcessingError.ffmpegNotFound` if FFmpeg is not available
    ///   - `ProcessingError.noValidSegments` if no segment files are found
    ///   - `FileSystemError` if file operations fail
    ///   - `ProcessingError` if FFmpeg execution fails
    public func combineSegments(in directory: URL, outputFile: URL) async throws {
        guard let ffmpegCommand = configuration.ffmpegPath else {
            throw ProcessingError.ffmpegNotFound()
        }
        
        // Use concurrent file processing
        let segmentFiles = try await findSegmentFiles(in: directory)
        
        guard !segmentFiles.isEmpty else {
            throw ProcessingError.noValidSegments()
        }
        
        // Create concat file with optimized I/O
        let concatFile = try await createConcatFile(segments: segmentFiles, in: directory)
        
        // Use FFmpeg with optimized parameters
        let arguments = buildConcatSegmentsFFmpegArguments(concatFile: concatFile, outputFile: outputFile)

        _ = try await commandExecutor.execute(
            command: ffmpegCommand,
            arguments: arguments,
            workingDirectory: directory.path
        )
    }
    
    /// Decrypts a single video segment using the provided key
    /// 
    /// This method decrypts an encrypted video segment and saves it to the specified
    /// output location. It supports various encryption methods and automatically
    /// detects hardware acceleration capabilities.
    /// 
    /// - Parameters:
    ///   - url: The URL of the encrypted segment file
    ///   - outputURL: The URL where the decrypted segment will be saved
    ///   - keyURL: Optional URL to the decryption key file
    /// 
    /// - Throws: 
    ///   - `ProcessingError.ffmpegNotFound` if FFmpeg is not available
    ///   - `ProcessingError` if FFmpeg execution fails or decryption fails
    public func decryptSegment(at url: URL, to outputURL: URL, keyURL: URL?) async throws {
        guard let ffmpegCommand = configuration.ffmpegPath else {
            throw ProcessingError.ffmpegNotFound()
        }
        
        var arguments = [
            "-y", // Overwrite output file
            "-protocol_whitelist", "file,http,https,tcp,tls,crypto",
            "-allowed_extensions", "ALL",
            "-i", url.path,
            "-c", "copy"
        ]
        
        // Add hardware acceleration if available
        if await checkHardwareAcceleration() {
            arguments.append(contentsOf: ["-hwaccel", "auto"])
        }
        
        arguments.append(outputURL.path)

        // Only set verbose mode when explicitly needed for debugging
        if configuration.logLevel >= .verbose {
            arguments.append(contentsOf: ["-v", "verbose"])
        }
        
        try await executeFFmpegWithRetry(
            command: ffmpegCommand,
            arguments: arguments,
            workingDirectory: outputURL.deletingLastPathComponent().path
        )
    }
    
    /// Decrypts and combines video segments into a single output file
    /// 
    /// This method uses FFmpeg to decrypt encrypted video segments referenced in an M3U8
    /// playlist file and combines them into a single output video file. It automatically
    /// detects hardware acceleration capabilities and uses them when available.
    /// 
    /// - Parameters:
    ///   - directory: The directory containing the video segments and M3U8 file
    ///   - localM3U8FileName: The name of the local M3U8 file that references the segments
    ///   - outputFile: The URL where the combined video file will be saved
    /// 
    /// - Throws: 
    ///   - `ProcessingError.ffmpegNotFound` if FFmpeg is not available
    ///   - `ProcessingError` if FFmpeg execution fails
    public func decryptAndCombineSegments(in directory: URL, with localM3U8FileName: String, outputFile: URL) async throws {
        guard let ffmpegCommand = configuration.ffmpegPath else {
            throw ProcessingError.ffmpegNotFound()
        }
        
        let m3u8File = directory.appendingPathComponent(localM3U8FileName)
        let formatM3U8File = try formatDecryptLocalM3U8File(url: m3u8File)

        do {
            // Method 1 - try formatM3U8File
            let arguments = await buildDecryptAndCombineSegmentsFFmpegArguments(m3u8File: formatM3U8File, outputFile: outputFile)
            try await executeFFmpegWithRetry(
                command: ffmpegCommand,
                arguments: arguments,
                workingDirectory: directory.path
            )
        } catch {
            // Method 2 - try ffmpeg buildin request
            let arguments = await buildDecryptAndCombineSegmentsFFmpegArguments(m3u8File: m3u8File, outputFile: outputFile)
            try await executeFFmpegWithRetry(
                command: ffmpegCommand,
                arguments: arguments,
                workingDirectory: directory.path
            )
        }
    }

    /// Rewrites segment URIs in a local decrypted M3U8 playlist.
    ///
    /// This method scans media playlist entries and converts each segment URI line
    /// (typically the line after `#EXTINF`) into a local file basename so FFmpeg can
    /// resolve sibling segment files from disk.
    ///
    /// - Parameter url: The source decrypted M3U8 file URL.
    /// - Returns: The URL of the rewritten local M3U8 file.
    ///
    /// - Throws:
    ///   - Any file read/write error when loading or saving playlist content.
    private func formatDecryptLocalM3U8File(url: URL) throws -> URL {
        let m3u8Content = try String(contentsOf: url, encoding: .utf8)
        var lines = m3u8Content.components(separatedBy: .newlines)
        var expectSegmentURI = false

        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("#EXTINF:") {
                expectSegmentURI = true
                continue
            }

            if expectSegmentURI {
                if trimmed.isEmpty {
                    continue
                }
                if trimmed.hasPrefix("#") {
                    expectSegmentURI = false
                    continue
                }

                lines[index] = URL(string: trimmed)?.lastPathComponent ?? URL(fileURLWithPath: trimmed).lastPathComponent
                expectSegmentURI = false
            }
        }

        let updatedContent = lines.joined(separator: "\n")
        let reformattedM3U8Path = url.deletingLastPathComponent().appendingPathComponent(Constants.FileNames.localM3U8Reformatted)
        try updatedContent.write(to: reformattedM3U8Path, atomically: true, encoding: .utf8)
        return reformattedM3U8Path
    }
    
    // MARK: - Private Optimized Methods
    
    /// Executes an FFmpeg command with retry logic for timeout errors
    /// 
    /// Since FFmpeg may request network resources (e.g., when processing M3U8 playlists
    /// with remote segments), this method implements retry logic with exponential backoff
    /// to handle transient network timeouts.
    /// 
    /// - Parameters:
    ///   - command: The FFmpeg command path
    ///   - arguments: Command arguments
    ///   - workingDirectory: Working directory for the command
    ///   - maxRetries: Maximum number of retry attempts (default: 3)
    /// 
    /// - Throws: ProcessingError if all retries are exhausted
    private func executeFFmpegWithRetry(
        command: String,
        arguments: [String],
        workingDirectory: String?,
        maxRetries: Int = 3
    ) async throws {
        let useVerboseLogging = configuration.logLevel >= .verbose
        
        for attempt in 0...maxRetries {
            do {
                // Always use executeWithResult to get both stdout and stderr
                let result = try await commandExecutor.executeWithResult(
                    command: command,
                    arguments: arguments,
                    workingDirectory: workingDirectory
                )
                
                guard result.isSuccess else {
                    // Log stderr output on failure (always useful for debugging)
                    if !result.stderr.isEmpty && useVerboseLogging {
                        Logger.verbose("FFmpeg error:\n\(result.stderr)", category: .processing)
                    }
                    throw ProcessingError.commandFailed(
                        command: command,
                        exitCode: result.exitCode,
                        output: result.stdout,
                        error: result.stderr
                    )
                }
                
                // Log FFmpeg verbose output from stderr when verbose mode is enabled
                if !result.stderr.isEmpty && useVerboseLogging {
                    Logger.verbose("FFmpeg output:\n\(result.stderr)", category: .processing)
                }
                
                // Success - log if retried
                if attempt > 0 {
                    Logger.info(
                        "FFmpeg command succeeded after \(attempt) retry attempt(s)",
                        category: .processing
                    )
                }
                return
                
            } catch {
                if attempt < maxRetries {
                    let delay = min(0.5 * pow(2.0, Double(attempt)), 5.0)
                    Logger.debug(
                        "FFmpeg command failed (attempt \(attempt + 1)/\(maxRetries + 1)): \(error.localizedDescription). Retrying in \(String(format: "%.1f", delay))s...",
                        category: .processing
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    break
                }
            }
        }
        
        // All retries exhausted
        throw ProcessingError.commandFailed(
            command: command,
            exitCode: -1,
            output: "",
            error: "Unknown error after \(maxRetries + 1) attempts"
        )
    }
    
    /// Finds all video segment files in the specified directory
    /// 
    /// This method efficiently scans a directory for `.ts` segment files and returns
    /// them sorted in the correct order for concatenation.
    /// 
    /// - Parameter directory: The directory to search for segment files
    /// 
    /// - Returns: An array of URLs to segment files, sorted by filename
    /// 
    /// - Throws: `FileSystemError` if directory access fails
    private func findSegmentFiles(in directory: URL) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let contents = try self.fileSystem.contentsOfDirectory(at: directory)
                    
                    // Filter and sort segments efficiently
                    let segmentFiles = contents
                        .filter { $0.pathExtension.lowercased() == "ts" }
                        .sorted { url1, url2 in
                            // Natural sort by filename
                            url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
                        }
                    
                    continuation.resume(returning: segmentFiles)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Creates a concat file for FFmpeg segment combination
    /// 
    /// This method creates a text file that FFmpeg can use to concatenate multiple
    /// video segments. The file is optimized for efficient I/O operations.
    /// 
    /// - Parameters:
    ///   - segments: Array of segment file URLs
    ///   - directory: The directory where the concat file will be created
    /// 
    /// - Returns: The URL of the created concat file
    /// 
    /// - Throws: `FileSystemError` if file creation fails
    private func createConcatFile(segments: [URL], in directory: URL) async throws -> URL {
        let concatURL = directory.appendingPathComponent(Constants.FileNames.fileList)
        
        // Use efficient string building
        let capacity = segments.count * 50 // Estimate capacity
        var fileListContent = String()
        fileListContent.reserveCapacity(capacity)
        
        for segment in segments {
            fileListContent += "file '\(segment.lastPathComponent)'\n"
        }
        
        try fileListContent.write(to: concatURL, atomically: true, encoding: .utf8)
        return concatURL
    }
    
    /// Builds optimized FFmpeg arguments for segment combination
    /// 
    /// This method creates an array of FFmpeg command-line arguments optimized
    /// for fast and efficient video segment combination.
    /// 
    /// - Parameters:
    ///   - concatFile: The URL of the concat file
    ///   - outputFile: The URL of the output video file
    /// 
    /// - Returns: An array of FFmpeg command-line arguments
    private func buildConcatSegmentsFFmpegArguments(concatFile: URL, outputFile: URL) -> [String] {
        var arguments = [
            "-f", "concat",
            "-safe", "0",
            "-i", concatFile.path,
            "-c", "copy",
            "-y", // Overwrite output file
            "-avoid_negative_ts", "make_zero",
            "-fflags", "+genpts"
        ]
        
        arguments.append(contentsOf: [
            "-movflags", "+faststart"
        ])
        
        arguments.append(outputFile.path)
        
        // Only set verbose mode when explicitly needed for debugging
        // FFmpeg's default log level is "info" which is sufficient for normal operation
        if configuration.logLevel >= .verbose {
            arguments.append(contentsOf: ["-v", "verbose", "-stats"])
        }   

        return arguments
    }

    /// Builds optimized FFmpeg arguments for decrypting and combining video segments
    /// 
    /// This method creates an array of FFmpeg command-line arguments optimized
    /// for fast and efficient video segment decryption and combination.
    /// 
    /// - Parameters:
    ///   - m3u8File: The URL of the M3U8 file
    ///   - outputFile: The URL of the output video file
    /// 
    /// - Returns: An array of FFmpeg command-line arguments
    private func buildDecryptAndCombineSegmentsFFmpegArguments(m3u8File: URL, outputFile: URL) async -> [String] {
        var arguments = [
            "-y", // Overwrite output file
            "-protocol_whitelist", "file,http,https,tcp,tls,crypto",
            "-allowed_extensions", "ALL"
        ]
        
        if await checkHardwareAcceleration() {
            arguments.append(contentsOf: ["-hwaccel", "auto"])
        }
        
        arguments.append(contentsOf: [
            "-i", m3u8File.path,
            "-c", "copy",
            outputFile.path
        ])
        
        // Only set verbose mode when explicitly needed for debugging
        // FFmpeg's default log level is "info" which is sufficient for normal operation
        if configuration.logLevel >= .verbose {
            arguments.append(contentsOf: ["-v", "verbose", "-stats"])
        }
        
        return arguments
    }
    
    /// Checks if hardware acceleration is available for video processing
    /// 
    /// This method queries FFmpeg to determine if hardware acceleration
    /// is available on the current system.
    /// 
    /// - Returns: `true` if hardware acceleration is available, `false` otherwise
    private func checkHardwareAcceleration() async -> Bool {
        // Check if hardware acceleration is available
        do {
            guard let ffmpegCommand = configuration.ffmpegPath else {
                return false
            }
            
            let result = try await commandExecutor.execute(
                command: ffmpegCommand,
                arguments: ["-hwaccels"],
                workingDirectory: nil
            )
            return result.contains("videotoolbox") || result.contains("vaapi")
        } catch {
            return false
        }
    }
}
