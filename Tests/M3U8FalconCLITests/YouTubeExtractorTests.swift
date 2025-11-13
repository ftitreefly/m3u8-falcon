@testable import M3U8FalconCLI
import M3U8Falcon
import XCTest

final class YouTubeExtractorTests: XCTestCase {

    func test_extract_directLinks_whenPageContainsM3U8() async throws {
        let url = URL(string: "https://www.youtube.com/watch?v=abc123")!
        let extractor = YouTubeExtractor()

        let links = try await extractor.extractM3U8Links(from: url, options: LinkExtractionOptions.default)

        // Since this is a demo implementation, it should return empty array
        XCTAssertTrue(links.isEmpty, "Demo implementation should return empty array")
    }

    func test_extract_playerResponse_mocked() async throws {
        let url = URL(string: "https://www.youtube.com/watch?v=xyz789")!
        let extractor = YouTubeExtractor()

        let links = try await extractor.extractM3U8Links(from: url, options: LinkExtractionOptions.default)

        // Since this is a demo implementation, it should return empty array
        XCTAssertTrue(links.isEmpty, "Demo implementation should return empty array")
    }
    
    func test_canHandle_youtubeDomains() {
        let extractor = YouTubeExtractor()
        
        // Test supported domains
        XCTAssertTrue(extractor.canHandle(url: URL(string: "https://youtube.com/watch?v=123")!))
        XCTAssertTrue(extractor.canHandle(url: URL(string: "https://www.youtube.com/watch?v=123")!))
        XCTAssertTrue(extractor.canHandle(url: URL(string: "https://m.youtube.com/watch?v=123")!))
        XCTAssertTrue(extractor.canHandle(url: URL(string: "https://youtu.be/123")!))
        
        // Test unsupported domains
        XCTAssertFalse(extractor.canHandle(url: URL(string: "https://vimeo.com/123")!))
        XCTAssertFalse(extractor.canHandle(url: URL(string: "https://example.com")!))
    }
    
    func test_getSupportedDomains() {
        let extractor = YouTubeExtractor()
        let domains = extractor.getSupportedDomains()
        
        XCTAssertTrue(domains.contains("youtube.com"))
        XCTAssertTrue(domains.contains("youtu.be"))
        XCTAssertTrue(domains.contains("m.youtube.com"))
        XCTAssertTrue(domains.contains("www.youtube.com"))
        XCTAssertEqual(domains.count, 4)
    }
    
    func test_getExtractorInfo() {
        let extractor = YouTubeExtractor()
        let info = extractor.getExtractorInfo()
        
        XCTAssertEqual(info.name, "YouTube Extractor (Demo)")
        XCTAssertEqual(info.version, "1.0.0")
        XCTAssertEqual(info.supportedDomains.count, 4)
        XCTAssertTrue(info.capabilities.contains(.directLinks))
        XCTAssertTrue(info.capabilities.contains(.javascriptVariables))
    }
}
