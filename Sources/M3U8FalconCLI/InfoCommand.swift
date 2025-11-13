//
//  InfoCommand.swift
//  M3U8FalconCLI
//
//  Created by tree_fly on 2025/7/13.
//

import ArgumentParser
import Foundation

/// Command for displaying tool information and version details
/// 
/// This command provides information about the M3U8Falcon CLI tool, including
/// version number, features, and basic usage instructions.
/// 
/// ## Usage Examples
/// ```bash
/// # Display tool information
/// m3u8-falcon info
/// 
/// # Get help for all commands
/// m3u8-falcon --help
/// ```
/// 
/// ## Output
/// The command displays:
/// - Tool version and description
/// - List of available features
/// - Basic usage instructions
/// - Help information
struct InfoCommand: ParsableCommand {
    /// Command configuration including name and description
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Display Tool Information",
        discussion: """
        Display detailed information about the M3U8Falcon CLI tool, including version number, features, and basic usage instructions.
        
        This command requires no parameters and directly displays complete tool information.
        """
    )
    
    /// Displays tool information and version details
    /// 
    /// This method prints comprehensive information about the M3U8Falcon CLI tool,
    /// including version number, feature list, and usage instructions.
    /// 
    /// The output includes:
    /// - Tool name and version
    /// - Description of the tool's purpose
    /// - List of main features and capabilities
    /// - Instructions for getting help
    mutating func run() {
        print("M3U8Falcon CLI v\(CLI.version)")
        print("A Swift Language based M3U8Falcon CLI tool")
        print("")
        print("Features:")
        print("  • Download M3U8 video files")
        print("  • Parse M3U8 playlists")
        print("  • Support for local and network files")
        print("  • Concurrent download support")
        print("  • Error retry mechanisms")
        print("")
        print("Use --help to view detailed help information")
        print("")
        print("Examples:")
        print("  m3u8-falcon info")
        print("  m3u8-falcon download https://example.com/video.m3u8 --name my-video -v")
        print("  m3u8-falcon extract \"https://example.com/video-page\" --methods direct-links")
    }
} 
