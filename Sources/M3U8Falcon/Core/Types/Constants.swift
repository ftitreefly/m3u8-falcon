//
//  Constants.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/7.
//

import Foundation

/// Constants used throughout the M3U8Falcon library
/// 
/// This enum provides a centralized location for all string constants,
/// reducing the risk of typos and making it easier to maintain consistent
/// naming across the codebase.
public enum Constants {
    /// File name constants used in M3U8 processing
    public enum FileNames {
        /// Local M3U8 playlist file name
        public static let localM3U8 = "local_file.m3u8"
        
        /// Decryption key file name
        public static let decryptionKey = "decryption_key.key"
        
        /// FFmpeg concat file list name
        public static let fileList = "file_list.txt"
    }
}

