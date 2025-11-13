//
//  ExtractCommand.swift
//  M3U8FalconCLI
//
//  Simplified demo command for extracting M3U8 links from web pages
//

import ArgumentParser
import Foundation
import M3U8Falcon

/// A simplified command for extracting M3U8 links from web pages
/// 
/// This command demonstrates the basic usage of the unified third-party interface
/// for extracting M3U8 links. It focuses on core functionality without complex
/// features like file output or advanced formatting.
/// 
/// ## Usage Examples
/// ```bash
/// # Basic extraction
/// m3u8-falcon extract "https://example.com/video-page"
/// 
/// # Show registered extractors
/// m3u8-falcon extract "https://example.com/video-page" --show-extractors
/// 
/// # Custom extraction methods
/// m3u8-falcon extract "https://example.com/video-page" --methods direct-links
/// ```
struct ExtractCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract M3U8 links from web pages using simplified methods",
        discussion: """
        This command demonstrates M3U8 link extraction using the unified interface.
        It automatically selects appropriate extractors based on the target URL domain.
        """,
        version: CLI.version
    )
    
    /// The URL of the web page to extract M3U8 links from
    @Argument(help: "URL of the web page to extract M3U8 links from")
    var url: String
    
    /// Extraction methods to use (comma-separated)
    @Option(name: .long, help: "Extraction methods to use (comma-separated)")
    var methods: String = "direct-links,javascript-variables"
    
    /// Whether to show extractor information
    @Flag(name: .long, help: "Show registered extractor information")
    var showExtractors: Bool = false
    
    /// Executes the M3U8 link extraction command
    /// 
    /// This method performs the main extraction workflow:
    /// 1. Validates the input URL
    /// 2. Creates and configures the extractor registry
    /// 3. Registers demo extractors
    /// 4. Optionally displays extractor information
    /// 5. Performs the extraction using the unified interface
    /// 6. Displays results in a simple format
    /// 
    /// - Throws: `ValidationError` if the URL is invalid, or errors from the extraction process
    func run() async throws {
        // Validate URL
        guard let targetURL = URL(string: url) else {
            throw ValidationError("Invalid URL: \(url)")
        }
        if let scheme = targetURL.scheme?.lowercased(), scheme != "http" && scheme != "https" {
            throw ValidationError("Unsupported URL scheme: \(scheme). Only http/https are supported.")
        }
        
        print("🔍 Starting M3U8 link extraction from: \(targetURL)")
        
        // Create extractor registry
        let registry = DefaultM3U8ExtractorRegistry()
        
        // Register demo extractors
        registry.registerExtractor(YouTubeExtractor())
        
        // Show extractor information if requested
        if showExtractors {
            displayExtractorInfo(registry)
        }
        
        // Parse extraction methods
        let extractionMethods = parseExtractionMethods(methods)
        
        // Create extraction options
        let options = LinkExtractionOptions(
            timeout: 30.0,
            maxRetries: 3,
            extractionMethods: extractionMethods,
            userAgent: nil,
            followRedirects: true,
            customHeaders: [:],
            executeJavaScript: true
        )
        
        do {
            // Extract M3U8 links
            let startTime = Date()
            let links = try await registry.extractM3U8Links(from: targetURL, options: options)
            let extractionTime = Date().timeIntervalSince(startTime)
            
            // Display results
            displayResults(links, extractionTime: extractionTime)
            
        } catch {
            print("❌ Extraction failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    /// Parses extraction methods from a comma-separated string
    /// 
    /// This method converts user-friendly method names into the corresponding
    /// `ExtractionMethod` enum values. It handles whitespace trimming and
    /// provides fallback to default methods if parsing fails.
    /// 
    /// ## Supported Methods
    /// - `direct-links` → `.directLinks`
    /// - `javascript-variables` → `.javascriptVariables`
    /// 
    /// ## Fallback Behavior
    /// If no valid methods are parsed, returns the default methods:
    /// `[.directLinks, .javascriptVariables]`
    /// 
    /// - Parameter methodsString: Comma-separated string of method names
    /// 
    /// - Returns: Array of parsed extraction methods
    private func parseExtractionMethods(_ methodsString: String) -> [ExtractionMethod] {
        let methodStrings = methodsString.split(separator: ",").map(String.init)
        var methods: [ExtractionMethod] = []
        
        for methodString in methodStrings {
            let trimmed = methodString.trimmingCharacters(in: .whitespaces)
            switch trimmed.lowercased() {
            case "direct-links":
                methods.append(.directLinks)
            case "javascript-variables":
                methods.append(.javascriptVariables)
            default:
                print("⚠️  Unknown extraction method: \(trimmed)")
            }
        }
        
        return methods.isEmpty ? [.directLinks, .javascriptVariables] : methods
    }
    
    /// Displays information about registered extractors
    /// 
    /// This method shows a formatted list of all registered extractors,
    /// including their names, versions, supported domains, and capabilities.
    /// This is useful for debugging and understanding which extractors
    /// are available for use.
    /// 
    /// - Parameter registry: The extractor registry to display information from
    private func displayExtractorInfo(_ registry: DefaultM3U8ExtractorRegistry) {
        print("📋 Registered Extractors:")
        let extractors = registry.getRegisteredExtractors()
        
        for extractor in extractors {
            print("  • \(extractor.name) v\(extractor.version)")
            print("    Domains: \(extractor.supportedDomains.joined(separator: ", "))")
            print("    Capabilities: \(extractor.capabilities.map { $0.description }.joined(separator: ", "))")
            print("    Status: \(extractor.isActive ? "Active" : "Inactive")")
            print()
        }
    }
    
    /// Displays the extraction results in a simple format
    /// 
    /// This method presents the extracted M3U8 links in a human-readable
    /// format, showing key information like URL, quality, extraction method,
    /// and confidence level for each link.
    /// 
    /// ## Display Format
    /// - Success message with extraction time
    /// - Number of links found
    /// - Detailed information for each link
    /// - Metadata if available
    /// 
    /// - Parameters:
    ///   - links: Array of extracted M3U8 links
    ///   - extractionTime: Time taken for the extraction process
    private func displayResults(_ links: [M3U8Link], extractionTime: TimeInterval) {
        print("✅ Extraction completed in \(String(format: "%.2f", extractionTime))s")
        print("🔗 Found \(links.count) M3U8 link(s):")
        print()
        
        if links.isEmpty {
            print("No M3U8 links were found on the target page.")
            return
        }
        
        for (index, link) in links.enumerated() {
            print("\(index + 1). \(link.url)")
            print("   Quality: \(link.quality ?? "Unknown")")
            print("   Method: \(link.extractionMethod.description)")
            print("   Confidence: \(String(format: "%.1f", link.confidence * 100))%")
            
            if !link.metadata.isEmpty {
                print("   Metadata:")
                for (key, value) in link.metadata {
                    print("     \(key): \(value)")
                }
            }
            print()
        }
    }
}
