//
//  DefaultM3U8LinkExtractor.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/1/27.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Default implementation of M3U8 link extraction from web pages
/// 
/// This class provides a comprehensive implementation for extracting M3U8 links
/// from various types of web pages using multiple extraction methods.
/// 
/// ## Features
/// - Direct M3U8 link detection in page source
/// - JavaScript variable extraction
/// - API endpoint discovery
/// - HTML video element parsing
/// - Regular expression pattern matching
/// - Support for multiple domains and platforms
/// 
/// ## Usage Example
/// ```swift
/// let extractor = DefaultM3U8LinkExtractor()
/// let options = LinkExtractionOptions.default
/// 
/// let links = try await extractor.extractM3U8Links(
///     from: URL(string: "https://example.com/video")!,
///     options: options
/// )
/// 
/// for link in links {
///     print("Found M3U8: \(link.url)")
///     print("Quality: \(link.quality ?? "Unknown")")
///     print("Confidence: \(link.confidence)")
/// }
/// ```
/// Default implementation of a general-purpose M3U8 link extractor.
///
/// Notes: Reuses a single URLSession to avoid connection churn; supports custom headers and User-Agent.
public final class DefaultM3U8LinkExtractor: M3U8LinkExtractorProtocol {
    
    /// Supported domains for this extractor
    private let supportedDomains: [String]
    private let networkClient: NetworkClientProtocol
    private let logger: LoggerProtocol
    
    /// Regular expressions for M3U8 link detection
    private let m3u8Patterns: [String] = [
        #"https?://[^\s"']+\.m3u8[^\s"']*"#,
        #"https?://[^\s"']+\.m3u8\?[^\s"']*"#,
        #"https?://[^\s"']+/playlist\.m3u8[^\s"']*"#,
        #"https?://[^\s"']+/master\.m3u8[^\s"']*"#,
        #"https?://[^\s"']+/index\.m3u8[^\s"']*"#
    ]
    
    /// JavaScript patterns for extracting M3U8 URLs
    private let jsPatterns: [String] = [
        #"['"`](https?://[^'`"]+\.m3u8[^'`"]*)['"`]"#,
        #"src\s*[:=]\s*['"`](https?://[^'`"]+\.m3u8[^'`"]*)['"`]"#,
        #"url\s*[:=]\s*['"`](https?://[^'`"]+\.m3u8[^'`"]*)['"`]"#,
        #"playlist\s*[:=]\s*['"`](https?://[^'`"]+\.m3u8[^'`"]*)['"`]"#
    ]
    
    /// Initializes a new default M3U8 link extractor
    /// 
    /// - Parameters:
    ///   - supportedDomains: Domain whitelist; empty means all domains are allowed
    ///   - networkClient: Networking client used to fetch page content
    ///   - logger: Logger implementation for diagnostic output
    public init(
        supportedDomains: [String] = [],
        networkClient: NetworkClientProtocol = DefaultNetworkClient(configuration: .performanceOptimized()),
        logger: LoggerProtocol = LoggerAdapter()
    ) {
        self.supportedDomains = supportedDomains
        self.logger = logger
        self.networkClient = networkClient
    }
    
    /// Extracts M3U8 links from a web page
    /// 
    /// This method implements a comprehensive extraction strategy using multiple
    /// methods to find M3U8 links in web pages.
    /// 
    /// - Parameters:
    ///   - url: The URL of the web page to analyze
    ///   - options: Configuration options for the extraction process
    /// 
    /// - Returns: Array of found M3U8 links with metadata
    /// 
    /// - Throws: 
    ///   - `NetworkError` if the web page cannot be accessed
    ///   - `ParsingError` if the page content cannot be parsed
    ///   - `ProcessingError` if no M3U8 links are found
    public func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
        logger.debug("Starting M3U8 link extraction from: \(url)", category: .extraction)
        
        var allLinks: [M3U8Link] = []
        
        // Download page content
        let pageContent = try await downloadPageContent(from: url, options: options)
        
        // Extract using different methods based on options
        for method in options.extractionMethods {
            let links = try await extractLinksUsingMethod(method, from: pageContent, baseURL: url, options: options)
            allLinks.append(contentsOf: links)
        }
        
        // Remove duplicates and sort by confidence
        let uniqueLinks = removeDuplicates(from: allLinks)
        let sortedLinks = uniqueLinks.sorted { $0.confidence > $1.confidence }
        
        logger.debug("Found \(sortedLinks.count) unique M3U8 links", category: .extraction)
        
        guard !sortedLinks.isEmpty else {
            throw ProcessingError.noM3U8LinksFound(url.absoluteString)
        }
        
        return sortedLinks
    }
    
    /// Returns a list of supported domains for this extractor
    /// 
    /// - Returns: Array of supported domain names
    public func getSupportedDomains() -> [String] {
        return supportedDomains
    }
    
    /// Checks if this extractor can handle the given URL
    /// 
    /// - Parameter url: The URL to check
    /// 
    /// - Returns: `true` if this extractor can handle the URL, `false` otherwise
    public func canHandle(url: URL) -> Bool {
        guard let host = url.host else { return false }
        
        // If no specific domains are configured, handle all URLs
        if supportedDomains.isEmpty {
            return true
        }
        
        return supportedDomains.contains { domain in
            host.hasSuffix(domain) || host == domain
        }
    }
    
    // MARK: - Private Methods
    
    /// Downloads page content from the given URL
    /// 
    /// - Parameters:
    ///   - url: Page URL
    ///   - options: Extraction options (timeout, headers, UA)
    /// - Returns: UTF-8 content string
    /// - Throws: `NetworkError` for non-200 responses; `ParsingError` on decoding failure
    private func downloadPageContent(from url: URL, options: LinkExtractionOptions) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = options.timeout
        
        // Set custom headers
        if let userAgent = options.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        
        for (key, value) in options.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await networkClient.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse(url)
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw ParsingError.invalidEncoding(url.absoluteString)
        }
        
        return content
    }

    // MARK: - Network
    
    /// Extracts links using a specific method
    private func extractLinksUsingMethod(_ method: ExtractionMethod, from content: String, baseURL: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
        switch method {
        case .directLinks:
            return extractDirectLinks(from: content, baseURL: baseURL)
        case .javascriptVariables:
            return extractFromJavaScript(from: content, baseURL: baseURL)
        case .videoElements:
            return extractFromVideoElements(from: content, baseURL: baseURL)
        default:
            return []
        }
    }
    
    /// Extracts direct M3U8 links from page content
    private func extractDirectLinks(from content: String, baseURL: URL) -> [M3U8Link] {
        var links: [M3U8Link] = []
        
        for pattern in m3u8Patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let urlString = String(content[range])
                        if let url = URL(string: urlString) {
                            let link = M3U8Link(
                                url: url,
                                extractionMethod: .directLinks,
                                confidence: 0.9
                            )
                            links.append(link)
                        }
                    }
                }
            } catch {
                logger.warning("Failed to compile regex pattern: \(pattern)", category: .extraction)
            }
        }
        
        return links
    }
    
    /// Extracts M3U8 links from JavaScript variables
    private func extractFromJavaScript(from content: String, baseURL: URL) -> [M3U8Link] {
        var links: [M3U8Link] = []
        
        for pattern in jsPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let urlString = String(content[range])
                        if let url = URL(string: urlString) {
                            let link = M3U8Link(
                                url: url,
                                extractionMethod: .javascriptVariables,
                                confidence: 0.8
                            )
                            links.append(link)
                        }
                    }
                }
            } catch {
                logger.warning("Failed to compile JavaScript regex pattern: \(pattern)", category: .extraction)
            }
        }
        
        return links
    }
    
    /// Extracts M3U8 links from HTML video elements
    private func extractFromVideoElements(from content: String, baseURL: URL) -> [M3U8Link] {
        var links: [M3U8Link] = []
        
        let videoPatterns = [
            #"<video[^>]*src\s*=\s*['"`]([^'`"]+\.m3u8[^'`"]*)['"`][^>]*>"#,
            #"<source[^>]*src\s*=\s*['"`]([^'`"]+\.m3u8[^'`"]*)['"`][^>]*>"#
        ]
        
        for pattern in videoPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                let range = NSRange(content.startIndex..<content.endIndex, in: content)
                let matches = regex.matches(in: content, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: content) {
                        let urlString = String(content[range])
                        if let url = URL(string: urlString) {
                            let link = M3U8Link(
                                url: url,
                                extractionMethod: .videoElements,
                                confidence: 0.85
                            )
                            links.append(link)
                        }
                    }
                }
            } catch {
                logger.warning("Failed to compile video element regex pattern: \(pattern)", category: .extraction)
            }
        }
        
        return links
    }
    
    /// Removes duplicate links based on URL
    private func removeDuplicates(from links: [M3U8Link]) -> [M3U8Link] {
        var seenURLs: Set<URL> = []
        var uniqueLinks: [M3U8Link] = []
        
        for link in links where !seenURLs.contains(link.url) {
            seenURLs.insert(link.url)
            uniqueLinks.append(link)
        }
        
        return uniqueLinks
    }
    
    /// Returns complete information about this extractor
    /// 
    /// This method returns a complete ExtractorInfo struct containing
    /// all metadata about this extractor. This allows the extractor
    /// to provide accurate information about its capabilities and
    /// supported domains.
    /// 
    /// - Returns: Complete extractor information
    public func getExtractorInfo() -> ExtractorInfo {
        return ExtractorInfo(
            name: "Default M3U8 Link Extractor",
            version: "1.0.0",
            supportedDomains: supportedDomains.isEmpty ? ["*"] : supportedDomains,
            capabilities: [.directLinks, .javascriptVariables, .videoElements]
        )
    }
}
