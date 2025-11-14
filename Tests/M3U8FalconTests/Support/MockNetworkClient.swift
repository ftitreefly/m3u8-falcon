//
//  MockNetworkClient.swift
//  M3U8FalconTests
//
//  Deterministic NetworkClientProtocol implementation for unit tests.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import M3U8Falcon

final class MockNetworkClient: NetworkClientProtocol, @unchecked Sendable {
    private struct Payload {
        let data: Data
        let response: URLResponse
    }
    
    private var responses: [URL: Result<Payload, Error>] = [:]
    private let lock = NSLock()
    
    func registerSuccess(
        url: URL,
        data: Data,
        statusCode: Int = 200,
        headers: [String: String] = [:]
    ) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            return
        }
        store(result: .success(Payload(data: data, response: response)), for: url)
    }
    
    func registerFailure(url: URL, error: Error) {
        store(result: .failure(error), for: url)
    }
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        let result = fetchResult(for: url)
        switch result {
        case .success(let payload):
            return (payload.data, payload.response)
        case .failure(let error):
            throw error
        case .none:
            throw URLError(.unsupportedURL)
        }
    }
    
    private func store(result: Result<Payload, Error>, for url: URL) {
        lock.lock()
        responses[url] = result
        lock.unlock()
    }
    
    private func fetchResult(for url: URL) -> Result<Payload, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return responses[url]
    }
}


