//
//  DefaultM3U8ExtractorRegistry.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/1/27.
//

import Foundation

/// Default implementation of M3U8 extractor registry
/// 
/// This class manages multiple M3U8 link extractors and routes requests
/// to the appropriate extractor based on the target URL domain.
/// 
/// ## Features
/// - Automatic extractor registration and management
/// - Domain-based routing to appropriate extractors
/// - Fallback to default extractor when no specific extractor is found
/// - Support for multiple extractors per domain
/// - Extractor information and status tracking
/// 
/// ## Usage Example
/// ```swift
/// let registry = DefaultM3U8ExtractorRegistry()
/// 
/// // Register specific extractors
/// registry.registerExtractor(YouTubeExtractor())
/// registry.registerExtractor(VimeoExtractor())
/// 
/// // Extract links (automatically routes to appropriate extractor)
/// let links = try await registry.extractM3U8Links(
///     from: URL(string: "https://youtube.com/watch?v=123")!,
///     options: LinkExtractionOptions.default
/// )
/// ```
public final class DefaultM3U8ExtractorRegistry: M3U8ExtractorRegistryProtocol, @unchecked Sendable {
    
    /// A single extractor registration record
    private struct Registration {
        let domain: String // e.g. "youtube.com" or "*"
        let priority: Int // higher wins
        let extractor: M3U8LinkExtractorProtocol
        let info: ExtractorInfo
    }
    
    /// Registered extractors bucketed by domain
    private var registrations: [String: [Registration]] = [:]
    
    /// Default extractor for fallback
    private let defaultExtractor: M3U8LinkExtractorProtocol
    
    /// Extractor metadata for tracking (flattened view)
    private var extractorMetadata: [String: ExtractorInfo] = [:]
    
    /// Initializes a new extractor registry
    /// 
    /// - Parameter defaultExtractor: Default extractor to use when no specific extractor is found
    private let logger: LoggerProtocol
    
    public init(defaultExtractor: M3U8LinkExtractorProtocol = DefaultM3U8LinkExtractor(), logger: LoggerProtocol = LoggerAdapter()) {
        self.defaultExtractor = defaultExtractor
        self.logger = logger
        
        // Register the default extractor
        registerDefaultExtractor()
    }
    
    /// Registers a new link extractor
    /// 
    /// This method registers an extractor and maps it to its supported domains.
    /// If multiple extractors support the same domain, the last registered one
    /// will be used for that domain.
    /// 
    /// - Parameter extractor: The extractor to register
    public func registerExtractor(_ extractor: M3U8LinkExtractorProtocol) {
        // Default priority for basic registration
        registerExtractor(extractor, priority: 100)
    }
    
    /// Registers a new extractor with a specific priority (higher wins).
    /// 
    /// Not part of the protocol to keep API surface minimal; provided as
    /// an extension API for advanced scenarios.
    public func registerExtractor(_ extractor: M3U8LinkExtractorProtocol, priority: Int) {
        let domains = extractor.getSupportedDomains()
        let name = String(describing: type(of: extractor))
        
        func append(domain: String) {
            let extractorInfo = extractor.getExtractorInfo()
            let reg = Registration(domain: domain, priority: priority, extractor: extractor, info: extractorInfo)
            registrations[domain, default: []].append(reg)
            extractorMetadata["\(extractorInfo.name)@\(domain)#\(priority)"] = extractorInfo
        }
        
        if domains.isEmpty {
            append(domain: "*")
        } else {
            for domain in domains { append(domain: domain) }
        }
        
        logger.debug("Registered extractor: \(name) priority=\(priority) for domains: \(domains.isEmpty ? ["*"] : domains)", category: .extraction)
    }
    
    /// Extracts M3U8 links using the appropriate registered extractor
    /// 
    /// This method automatically selects the appropriate extractor based on
    /// the URL domain and delegates the extraction to it. If no specific
    /// extractor is found, it falls back to the default extractor.
    /// 
    /// - Parameters:
    ///   - url: The URL of the web page to analyze
    ///   - options: Configuration options for the extraction process
    /// 
    /// - Returns: Array of found M3U8 links with metadata
    /// 
    /// - Throws: 
    ///   - `ProcessingError` if no suitable extractor is found
    ///   - Various errors from the selected extractor
    public func extractM3U8Links(from url: URL, options: LinkExtractionOptions) async throws -> [M3U8Link] {
        guard let host = url.host else {
            throw ProcessingError.invalidURL(url.absoluteString)
        }
        
        // Collect candidate registrations by matching domain rules
        let candidates = candidateRegistrations(forHost: host)
        
        // Ensure the default extractor is always considered at lowest priority
        let defaultInfo = defaultExtractor.getExtractorInfo()
        let allCandidates: [Registration] = candidates.isEmpty ? [Registration(domain: "*", priority: Int.min, extractor: defaultExtractor, info: defaultInfo)] : candidates
        
        // Sort by priority (desc), then more specific domain first (longer string)
        let sorted = allCandidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.domain.count > rhs.domain.count
        }
        
        logger.debug("Extractor candidates for host \(host): \(sorted.map { "\($0.info.name)@\($0.domain)#\($0.priority)" }.joined(separator: ", "))", category: .extraction)
        
        // Run candidates concurrently, merge all successful results
        var collected: [[M3U8Link]] = []
        var failures: [Error] = []
        
        await withTaskGroup(of: Result<[M3U8Link], Error>.self) { group in
            for reg in sorted {
                group.addTask {
                    do {
                        let links = try await reg.extractor.extractM3U8Links(from: url, options: options)
                        return .success(links)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            for await result in group {
                switch result {
                case .success(let links):
                    if !links.isEmpty { collected.append(links) }
                case .failure(let error):
                    failures.append(error)
                }
            }
        }
        
        let merged = mergeAndSort(linksArrays: collected)
        if !merged.isEmpty { return merged }
        
        // If everything failed or produced nothing, fallback to default explicitly
        do {
            let fallback = try await defaultExtractor.extractM3U8Links(from: url, options: options)
            let deduped = mergeAndSort(linksArrays: [fallback])
            if !deduped.isEmpty { return deduped }
        } catch {
            failures.append(error)
        }
        
        // Return an aggregated error
        throw ProcessingError.noM3U8LinksFound(url.absoluteString)
    }
    
    /// Gets a list of all registered extractors
    /// 
    /// This method returns information about all registered extractors,
    /// useful for debugging and monitoring purposes.
    /// 
    /// - Returns: Array of extractor information
    public func getRegisteredExtractors() -> [ExtractorInfo] {
        return Array(extractorMetadata.values)
    }
    
    // MARK: - Private Methods
    
    /// Registers the default extractor
    private func registerDefaultExtractor() {
        let info = defaultExtractor.getExtractorInfo()
        let reg = Registration(domain: "*", priority: Int.min, extractor: defaultExtractor, info: info)
        registrations["*", default: []].append(reg)
        extractorMetadata["Default@*#\(Int.min)"] = info
    }
    
    /// Finds candidate extractor registrations for a host
    /// 
    /// The result is a deduplicated list of registrations that match the host
    /// by exact domain, suffix domain (subdomain), or wildcard.
    /// 
    /// - Parameter host: The host to evaluate
    /// - Returns: Matching registrations (not sorted)
    private func candidateRegistrations(forHost host: String) -> [Registration] {
        var result: [Registration] = []
        
        // Exact domain
        if let regs = registrations[host] { result.append(contentsOf: regs) }
        
        // Suffix matches (e.g., sub.domain.com matches domain.com)
        for (domain, regs) in registrations where domain != "*" && host.hasSuffix(domain) && domain != host {
            result.append(contentsOf: regs)
        }
        
        // Wildcard
        if let wildcard = registrations["*"] { result.append(contentsOf: wildcard) }
        
        // Deduplicate same extractor instance-domain by keeping highest priority
        var seen: [String: Registration] = [:]
        var filtered: [Registration] = []
        for reg in result {
            let key = "\(reg.info.name)@\(reg.domain)"
            if let existing = seen[key] {
                if reg.priority > existing.priority { seen[key] = reg }
            } else {
                seen[key] = reg
            }
        }
        filtered.append(contentsOf: seen.values)
        return filtered
    }
    
    private func mergeAndSort(linksArrays: [[M3U8Link]]) -> [M3U8Link] {
        var unique: [String: M3U8Link] = [:]
        for arr in linksArrays {
            for link in arr {
                let key = link.url.absoluteString
                if let existing = unique[key] {
                    // Keep the higher confidence link
                    if link.confidence > existing.confidence { unique[key] = link }
                } else {
                    unique[key] = link
                }
            }
        }
        return Array(unique.values).sorted { $0.confidence > $1.confidence }
    }
}

// MARK: - Convenience Extensions

extension DefaultM3U8ExtractorRegistry {
    
    /// Registers multiple extractors at once
    /// 
    /// This convenience method allows registering multiple extractors
    /// in a single call.
    /// 
    /// - Parameter extractors: Array of extractors to register
    public func registerExtractors(_ extractors: [M3U8LinkExtractorProtocol]) {
        for extractor in extractors {
            registerExtractor(extractor)
        }
    }

    /// Registers extractor with an explicit priority (higher wins)
    public func registerExtractorWithPriority(_ extractor: M3U8LinkExtractorProtocol, priority: Int) {
        registerExtractor(extractor, priority: priority)
    }
    
    /// Unregisters an extractor for a specific domain
    /// 
    /// This method removes an extractor from the registry for the specified domain.
    /// 
    /// - Parameter domain: The domain to unregister the extractor from
    public func unregisterExtractor(for domain: String) {
        registrations.removeValue(forKey: domain)
        // Remove metadata entries that reference this domain
        extractorMetadata = extractorMetadata.filter { key, _ in
            return !key.contains("@\(domain)#")
        }
        logger.debug("Unregistered extractors for domain: \(domain)", category: .extraction)
    }
    
    /// Checks if an extractor is registered for a domain
    /// 
    /// - Parameter domain: The domain to check
    /// 
    /// - Returns: `true` if an extractor is registered for the domain, `false` otherwise
    public func hasExtractor(for domain: String) -> Bool {
        guard let regs = registrations[domain] else { return false }
        return !regs.isEmpty
    }
    
    /// Gets the extractor for a specific domain
    /// 
    /// - Parameter domain: The domain to get the extractor for
    /// 
    /// - Returns: The extractor for the domain, or `nil` if not found
    public func getExtractor(for domain: String) -> M3U8LinkExtractorProtocol? {
        guard let regs = registrations[domain], !regs.isEmpty else { return nil }
        return regs.max(by: { $0.priority < $1.priority })?.extractor
    }
}
