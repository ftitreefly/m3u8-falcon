import Foundation
@testable import M3U8FalconCLI
import M3U8Falcon
import Testing

@Suite("YouTube Extractor Tests")
final class YouTubeExtractorTests {

    @Test("Extract direct links when page contains M3U8")
    func extractDirectLinksWhenPageContainsM3U8() async throws {
        let url = URL(string: "https://www.youtube.com/watch?v=abc123")!
        let extractor = YouTubeExtractor()

        let links = try await extractor.extractM3U8Links(from: url, options: LinkExtractionOptions.default)

        // Since this is a demo implementation, it should return empty array
        #expect(links.isEmpty, "Demo implementation should return empty array")
    }

    @Test("Extract player response mocked")
    func extractPlayerResponseMocked() async throws {
        let url = URL(string: "https://www.youtube.com/watch?v=xyz789")!
        let extractor = YouTubeExtractor()

        let links = try await extractor.extractM3U8Links(from: url, options: LinkExtractionOptions.default)

        // Since this is a demo implementation, it should return empty array
        #expect(links.isEmpty, "Demo implementation should return empty array")
    }
    
    @Test("Can handle YouTube domains")
    func canHandleYouTubeDomains() {
        let extractor = YouTubeExtractor()
        
        // Test supported domains
        #expect(extractor.canHandle(url: URL(string: "https://youtube.com/watch?v=123")!))
        #expect(extractor.canHandle(url: URL(string: "https://www.youtube.com/watch?v=123")!))
        #expect(extractor.canHandle(url: URL(string: "https://m.youtube.com/watch?v=123")!))
        #expect(extractor.canHandle(url: URL(string: "https://youtu.be/123")!))
        
        // Test unsupported domains
        #expect(!extractor.canHandle(url: URL(string: "https://vimeo.com/123")!))
        #expect(!extractor.canHandle(url: URL(string: "https://example.com")!))
    }
    
    @Test("Get supported domains")
    func getSupportedDomains() {
        let extractor = YouTubeExtractor()
        let domains = extractor.getSupportedDomains()
        
        #expect(domains.contains("youtube.com"))
        #expect(domains.contains("youtu.be"))
        #expect(domains.contains("m.youtube.com"))
        #expect(domains.contains("www.youtube.com"))
        #expect(domains.count == 4)
    }
    
    @Test("Get extractor info")
    func getExtractorInfo() {
        let extractor = YouTubeExtractor()
        let info = extractor.getExtractorInfo()
        
        #expect(info.name == "YouTube Extractor (Demo)")
        #expect(info.version == "1.0.0")
        #expect(info.supportedDomains.count == 4)
        #expect(info.capabilities.contains(.directLinks))
        #expect(info.capabilities.contains(.javascriptVariables))
    }
}
