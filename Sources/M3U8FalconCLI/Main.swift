//
//  Main.swift
//  M3U8CLI
//
//  Created by tree_fly on 2025/7/13.
//

import ArgumentParser
import Foundation
import M3U8Falcon

/// M3U8Falcon Command Line Interface
@main
struct M3U8FalconCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "m3u8-falcon",
        abstract: "M3U8Falcon Command Line Interface",
        discussion: """
        This tool supports downloading and parsing M3U8 video files.
        Supports downloading from URLs or processing local files.
        """,
        version: CLI.version,
        subcommands: [
            DownloadCommand.self,
            InfoCommand.self,
            ExtractCommand.self
        ]
    )
}

enum CLI {
    static let version = "1.0.0"
}
