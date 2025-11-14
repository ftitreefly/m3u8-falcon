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
/// # Download with verbose output
/// m3u8-falcon download https://example.com/video.m3u8 -v
/// 
/// # Download with both custom name and verbose output
/// m3u8-falcon download https://example.com/video.m3u8 --name my-video -v
/// ```
/// 
/// ## Output
/// Downloaded files will be saved to the user's Downloads directory with the following structure:
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
        - Customizable output filename
        - Detailed download progress information
        - Error handling and retry mechanisms
        - Support for encrypted M3U8 files with custom decryption key and IV
        
        Downloaded files will be saved to the user's Downloads directory by default.
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

    /// Enable verbose output for detailed download information
    /// 
    /// When enabled, provides detailed information about the download process,
    /// including progress updates, file sizes, and timing information.
    @Flag(name: [.short], help: "Show verbose output")
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
    /// 4. Saves files to the Downloads directory
    /// 5. Provides status updates and error handling
    /// 
    /// - Throws: 
    ///   - `ExitCode.failure` if URL is invalid or download fails
    ///   - Various network and file system errors during download
    mutating func run() async throws {
        try await validateFFmpegAvailability()

        // Ensure DI is configured (idempotent)
        await M3U8Falcon.initialize()

        let outputDirectory = await resolveOutputDirectory()
            
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
            
            try await M3U8Falcon.download(
                .web,
                url: downloadURL,
                savedDirectory: outputDirectory,
                name: name,
                verbose: verbose,
                key: key,
                iv: iv
            )
            if verbose { OutputFormatter.printSuccess("Download completed!") }
        } catch {
            if let tfErr = error as? (any M3U8FalconError) {
                let suggestion = tfErr.recoverySuggestion ?? ""
                OutputFormatter.printError("Download failed [\(tfErr.code)]: \(tfErr.localizedDescription)\(suggestion.isEmpty ? "" : " | Suggestion: \(suggestion)")")
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

    /// Resolves the default output directory, handling Linux-specific cases
    func resolveOutputDirectory() async -> URL {
        if let provider = try? await GlobalDependencies.shared.resolve(PathProviderProtocol.self) {
            let directory = provider.downloadsDirectory()
            if ensureDirectoryExists(directory) {
                return directory
            }
        }

        #if os(Linux)
        if let xdgPath = resolveXDGDownloadDir(), ensureDirectoryExists(xdgPath) {
            return xdgPath
        }
        #endif

        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        _ = ensureDirectoryExists(fallback)
        return fallback
    }

    @discardableResult
    func ensureDirectoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            OutputFormatter.printWarning("Failed to create directory at \(url.path): \(error.localizedDescription)")
            return false
        }
    }

    #if os(Linux)
    func resolveXDGDownloadDir() -> URL? {
        if let envPath = ProcessInfo.processInfo.environment["XDG_DOWNLOAD_DIR"], !envPath.isEmpty {
            return normalizeXDGPath(envPath)
        }

        let configFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("user-dirs.dirs", isDirectory: false)

        guard let contents = try? String(contentsOf: configFile, encoding: .utf8) else {
            return nil
        }

        for line in contents.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("XDG_DOWNLOAD_DIR=") else { continue }

            let valueStart = trimmed.index(trimmed.startIndex, offsetBy: "XDG_DOWNLOAD_DIR=".count)
            var value = trimmed[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            if let url = normalizeXDGPath(String(value)) {
                return url
            }
        }

        return nil
    }

    func normalizeXDGPath(_ rawPath: String) -> URL? {
        guard !rawPath.isEmpty else { return nil }
        var path = rawPath
        
        // Expand all environment variables in the format $VAR or ${VAR}
        let environment = ProcessInfo.processInfo.environment
        
        // Pattern for ${VAR} format
        var pattern = #/\$\{([A-Z_][A-Z0-9_]*)\}/#
        while let match = path.firstMatch(of: pattern) {
            let varName = String(match.1)
            if let value = environment[varName] {
                path = path.replacingOccurrences(of: "${\(varName)}", with: value)
            } else {
                // If variable not found, leave it as is or remove
                path = path.replacingOccurrences(of: "${\(varName)}", with: "")
            }
        }
        
        // Pattern for $VAR format (word boundary)
        pattern = #/\$([A-Z_][A-Z0-9_]*)/#
        while let match = path.firstMatch(of: pattern) {
            let varName = String(match.1)
            if let value = environment[varName] {
                path = path.replacingOccurrences(of: "$\(varName)", with: value)
            } else {
                // If variable not found, leave it as is or remove
                path = path.replacingOccurrences(of: "$\(varName)", with: "")
            }
        }
        
        // Expand tilde after environment variables (in case ~ was in an env var)
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }
        
        // Final validation - path must be absolute after expansion
        guard path.hasPrefix("/") else {
            return nil
        }
        
        return URL(fileURLWithPath: path, isDirectory: true)
    }
    #endif
}
