//
//  NoopCommandExecutor.swift
//  M3U8FalconTests
//
//  Lightweight stub for CommandExecutorProtocol used in downloader tests.
//

import Foundation
@testable import M3U8Falcon

struct NoopCommandExecutor: CommandExecutorProtocol {
    func execute(command: String, arguments: [String], workingDirectory: String?) async throws -> String {
        return ""
    }
}


