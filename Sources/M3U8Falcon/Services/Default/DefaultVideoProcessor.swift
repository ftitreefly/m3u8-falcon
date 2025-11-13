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
///     configuration: configuration
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
    
    /// Initializes a new default video processor
    /// 
    /// - Parameters:
    ///   - commandExecutor: The command executor for running external commands
    ///   - configuration: Configuration settings for video processing
    public init(commandExecutor: CommandExecutorProtocol, configuration: DIConfiguration) {
        self.commandExecutor = commandExecutor
        self.configuration = configuration
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
    ///   - `ProcessingError` with code 4007 if no segment files are found
    ///   - `FileSystemError` if file operations fail
    ///   - `CommandExecutionError` if FFmpeg execution fails
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
    ///   - `FileSystemError` if file operations fail
    ///   - `CommandExecutionError` if FFmpeg execution fails
    ///   - `ProcessingError` if decryption fails
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
        
        // Add performance settings
#if DEBUG
        arguments.append(contentsOf: ["-v", "verbose"])
#else
        arguments.append(contentsOf: ["-v", "quiet", "-nostats"])
#endif
        
        _ = try await commandExecutor.execute(
            command: ffmpegCommand,
            arguments: arguments,
            workingDirectory: outputURL.deletingLastPathComponent().path
        )
    }
    
    /// Decrypts and combines video segments into a single output file
    /// 
    /// This method decrypts an encrypted video segment and saves it to the specified
    /// output location. It supports various encryption methods and automatically
    /// detects hardware acceleration capabilities.
    /// 
    /// - Parameters:
    ///   - directory: The directory containing the video segments
    ///   - localM3U8FileName: The name of the local M3U8 file
    ///   - outputFile: The URL where the combined video file will be saved
    /// 
    /// - Throws: 
    ///   - `ProcessingError` with code 4007 if no segment files are found
    ///   - `FileSystemError` if file operations fail
    ///   - `CommandExecutionError` if FFmpeg execution fails
    public func decryptAndCombineSegments(in directory: URL, with localM3U8FileName: String, outputFile: URL) async throws {
        guard let ffmpegCommand = configuration.ffmpegPath else {
            throw ProcessingError.ffmpegNotFound()
        }
        
        let m3u8File = directory.appendingPathComponent(localM3U8FileName)
        
        let arguments = await buildDecryptAndCombineSegmentsFFmpegArguments(m3u8File: m3u8File, outputFile: outputFile)
        
        _ = try await commandExecutor.execute(
            command: ffmpegCommand,
            arguments: arguments,
            workingDirectory: directory.path
        )   
    }
    
    // MARK: - Private Optimized Methods
    
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
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                        options: .skipsHiddenFiles
                    )
                    
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
        let concatURL = directory.appendingPathComponent("filelist.txt")
        
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
        
        // Add performance optimizations
        arguments.append(contentsOf: [
            "-threads", "0", // Use all available threads
            "-preset", "ultrafast", // Fastest encoding
            "-tune", "fastdecode" // Optimize for fast decoding
        ])
        
        arguments.append(outputFile.path)
        
        // Add quiet mode for production
#if !DEBUG
        arguments.append(contentsOf: ["-v", "quiet", "-nostats"])
#endif
        
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
        
        // Add quiet mode for production
#if !DEBUG
        arguments.append(contentsOf: ["-v", "quiet", "-nostats"])
#endif
        
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


