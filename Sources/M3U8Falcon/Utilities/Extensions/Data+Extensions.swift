//
//  Data+Extensions.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/7.
//

import Foundation

extension Data {
    /// Initializes Data from a hexadecimal string
    /// 
    /// This initializer converts a hexadecimal string representation into Data.
    /// The string should contain only hexadecimal characters (0-9, a-f, A-F).
    /// 
    /// - Parameter hexString: A hexadecimal string (e.g., "0123456789abcdef")
    /// 
    /// ## Usage Example
    /// ```swift
    /// let data = Data(hexString: "48656c6c6f")  // "Hello" in hex
    /// let key = Data(hexString: "0123456789abcdef0123456789abcdef")
    /// ```
    init?(hexString: String) {
        // Remove any whitespace
        let cleanString = hexString.replacingOccurrences(of: " ", with: "")
        
        // Check if string length is even
        guard cleanString.count % 2 == 0 else {
            return nil
        }
        
        var data = Data(capacity: cleanString.count / 2)
        
        var index = cleanString.startIndex
        while index < cleanString.endIndex {
            let nextIndex = cleanString.index(index, offsetBy: 2)
            let byteString = cleanString[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            
            data.append(byte)
            index = nextIndex
        }
        
        self = data
    }
    
    /// Converts Data to a hexadecimal string representation
    /// 
    /// This method converts the data bytes into a hexadecimal string.
    /// 
    /// - Parameter uppercase: Whether to use uppercase letters (default: false)
    /// 
    /// - Returns: A hexadecimal string representation of the data
    /// 
    /// ## Usage Example
    /// ```swift
    /// let data = Data([0x48, 0x65, 0x6c, 0x6c, 0x6f])
    /// print(data.hexString())  // "48656c6c6f"
    /// print(data.hexString(uppercase: true))  // "48656C6C6F"
    /// ```
    func hexString(uppercase: Bool = false) -> String {
        let format = uppercase ? "%02X" : "%02x"
        return map { String(format: format, $0) }.joined()
    }
}

