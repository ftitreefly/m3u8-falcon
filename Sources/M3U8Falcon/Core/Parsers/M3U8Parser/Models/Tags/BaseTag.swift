//
//  BaseTag.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/7/13.
//
//  Some code in this file is referenced or adapted from go-swifty-m3u8 (https://github.com/gal-orlanczyk/go-swifty-m3u8)
//  Copyright (c) Gal Orlanczyk
//  Licensed under the MIT License.
//
//  The MIT License (MIT)
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

/// `BaseTag` represents a base tag that holds minimal tag info.
/// This class is now compatible with the modern error handling system.
public class BaseTag: TagWithValue, @unchecked Sendable {
    /// The tag itself, for example: '#EXTM3U'
    public class var tag: String { 
        return "#UNKNOWN" // Default implementation
    }
    
    /// The text string of the line (the actual original data for each line)
    public let text: String
    
    /// The tag text data - all of the text after the tag.
    /// For example: '#EXTINF:4.458667,' tagDataText = '4.458667,'
    public let tagDataText: String
    
    /// The tag type, used to help subclass of base tags to identify the real type of the object.
    public let tagType: any Tag.Type
    
    /// The value of the tag, for example if tag is #EXTINF:8.0,\n then value is 8.0
    public var value: Any { return tagDataText }
    
    /// Initializes a tag with single value.
    /// - Parameters:
    ///   - text: The tag text
    ///   - tagType: The tag type
    ///   - extraParams: Extra parameters for tag parsing
    public required init(text: String, tagType: any Tag.Type, extraParams: [String: Any]?) throws {
        self.text = text
        self.tagDataText = text.getTagValue(forType: tagType)
        self.tagType = tagType
    }
    
    /// Safe conversion to specific type with error handling
    public func asType<T>(_ type: T.Type) throws(ParsingError) -> T {
        guard let converted = self as? T else {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "\(String(describing: T.self))",
                received: "\(self.tagDataText)"
            )
        }
        return converted
    }
}

/// A base tag that represent tags with single value.
/// This class now uses modern error handling instead of fatalError.
public class BaseValueTag<T: StringInitializable & Sendable>: TagWithValue, @unchecked Sendable {
    /// The tag itself, for example: '#EXTM3U'
    public class var tag: String { 
        return "#UNKNOWN" // Default implementation
    }
    
    /// The text string of the line (the actual original data for each line)
    public let text: String
    
    /// The tag text data - all of the text after the tag.
    /// For example: '#EXTINF:4.458667,' tagDataText = '4.458667,'
    public let tagDataText: String
    
    /// The tag type, used to help subclass of base tags to identify the real type of the object.
    public let tagType: any Tag.Type
    
    /// The value of the tag in the type provided.
    public let value: T
    
    /// Initializes a tag with single value.
    /// - Parameters:
    ///   - text: The tag text
    ///   - tagType: The tag type
    ///   - extraParams: Extra parameters for tag parsing
    public required init(text: String, tagType: any Tag.Type, extraParams: [String: Any]?) throws {
        let baseTag = try BaseTag(text: text, tagType: tagType, extraParams: nil)
        self.text = baseTag.text
        self.tagDataText = baseTag.tagDataText
        self.tagType = baseTag.tagType
        
        if let value = T(self.tagDataText) {
            self.value = value
        } else {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "\(String(describing: T.self))",
                received: "\(self.tagDataText)"
            )
        }
    }
}

/// A base attribute tag, that holds tag info + attributes.
/// This class now uses modern error handling instead of fatalError.
public class BaseAttributedTag: AttributedTag, @unchecked Sendable {
    /// The tag itself, for example: '#EXTM3U'
    public class var tag: String { 
        return "#UNKNOWN" // Default implementation
    }
    
    /// The text string of the line (the actual original data for each line)
    public let text: String
    
    /// The tag text data - all of the text after the tag.
    /// For example: '#EXTINF:4.458667,' tagDataText = '4.458667,'
    public let tagDataText: String
    
    /// The tag type, used to help subclass of base tags to identify the real type of the object.
    public let tagType: any Tag.Type
    
    /// The attributes of the tag.
    public let attributes: [String: String]
    
    /// Initializes a tag with attributes.
    /// - Parameters:
    ///   - text: The tag text
    ///   - tagType: The tag type
    ///   - extraParams: Extra parameters for tag parsing
    public required init(text: String, tagType: any Tag.Type, extraParams: [String: Any]?) throws {
        let baseTag = try BaseTag(text: text, tagType: tagType, extraParams: nil)
        self.text = baseTag.text
        self.tagDataText = baseTag.tagDataText
        self.tagType = baseTag.tagType
        
        // Use extra params to get the required attributes
        guard let separator = extraParams?[TagParamsKeys.attributesSeperator] as? String,
              let attributesCount = extraParams?[TagParamsKeys.attributesCount] as? Int,
              let attributeKeys = extraParams?[TagParamsKeys.attributesKeys] as? [String]
        else { 
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "required parameters (separator, count, keys)",
                received: "missing parameters"
            )
        }
        
        let extrasToRemove = extraParams?[TagParamsKeys.attributesExtrasToRemove] as? [String]
        
        guard let attributedTagType = tagType as? any AttributedTag.Type else {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "AttributedTag type",
                received: "\(String(describing: tagType))"
            )
        }
        
        self.attributes = attributedTagType.getAttributes(
            from: self.tagDataText,
            seperatedBy: separator,
            extrasToRemove: extrasToRemove
        )
        
        if attributes.isEmpty {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "at least \(attributesCount) attributes",
                received: "0 attributes"
            )
        }
        
        // Validate integrity using modern error handling
        do {
            try self.validateIntegrity(requiredAttributes: attributeKeys)
        } catch {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "required attributes: \(attributeKeys.joined(separator: ", "))",
                received: "missing some required attributes"
            )
        }
    }
    
    /// Safe attribute validation with modern error handling
    public func validateAttributeCount(_ expected: Int) throws(ParsingError) {
        guard attributes.count >= expected else {
            throw ParsingError.invalidTag(
                tagType.tag,
                expected: "at least \(expected) attributes",
                received: "\(attributes.count) attributes"
            )
        }
    }
}

// MARK: - Safe Tag Creation

/// Utility functions for creating tags with proper error handling
public enum TagCreation {
    /// Creates a tag with proper error handling instead of fatalError
    public static func createTag<T: Tag>(
        _ type: T.Type,
        text: String,
        extraParams: [String: Any]? = nil
    ) throws(ParsingError) -> T {
        do {
            return try T(text: text, tagType: type, extraParams: extraParams)
        } catch let error as ParsingError {
            throw error
        } catch {
            throw ParsingError(
                code: 2003,
                underlyingError: error,
                message: "Failed to create tag: \(type.tag)",
                context: "Text: \(text)"
            )
        }
    }
}
