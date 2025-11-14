//
//  MockURLProtocol.swift
//  M3U8FalconTests
//
//  Provides a deterministic URL loading system for unit tests by intercepting
//  URLSession requests and returning predefined responses.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockURLProtocol: URLProtocol {
    struct MockResponse {
        let statusCode: Int
        let headers: [String: String]
        let data: Data
    }
    
    private static let handlerStore = HandlerStore()
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        guard let handler = Self.handler(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        
        switch handler {
        case .success(let response):
            guard let httpResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
    
    // MARK: - Registration
    
    static func registerSuccess(
        for url: URL,
        statusCode: Int = 200,
        headers: [String: String] = [:],
        data: Data
    ) {
        let response = MockResponse(statusCode: statusCode, headers: headers, data: data)
        handlerStore.register(url: url, result: .success(response))
    }
    
    static func registerFailure(for url: URL, error: Error) {
        handlerStore.register(url: url, result: .failure(error))
    }
    
    static func reset() {
        handlerStore.reset()
    }
    
    static func makeEphemeralConfiguration(timeoutSeconds: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeoutSeconds
        config.timeoutIntervalForResource = timeoutSeconds
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }
    
    private static func handler(for url: URL) -> Result<MockResponse, Error>? {
        handlerStore.handler(for: url)
    }
}

private final class HandlerStore: @unchecked Sendable {
    private var handlers: [URL: Result<MockURLProtocol.MockResponse, Error>] = [:]
    private let lock = NSLock()
    
    func register(url: URL, result: Result<MockURLProtocol.MockResponse, Error>) {
        lock.lock()
        handlers[url] = result
        lock.unlock()
    }
    
    func handler(for url: URL) -> Result<MockURLProtocol.MockResponse, Error>? {
        lock.lock()
        let value = handlers[url]
        lock.unlock()
        return value
    }
    
    func reset() {
        lock.lock()
        handlers.removeAll()
        lock.unlock()
    }
}


