//
//  LinuxStreamingNetworkClient.swift
//  M3U8Falcon
//
//  Created by tree_fly on 2025/11/14.
//

#if !canImport(Darwin)
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Linux-specific streaming network client using URLSessionDataDelegate
final class LinuxStreamingNetworkClient: StreamingNetworkClientProtocol {
    private let configuration: URLSessionConfiguration
    
    init(configuration: URLSessionConfiguration) {
        self.configuration = configuration
    }
    
    func fetchAsyncBytes(from url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>) {
        let fetcher = ByteStreamFetcher(configuration: configuration)
        return try await fetcher.start(url: url)
    }
}

/// Fetches data as a byte stream using URLSessionDataDelegate
private final class ByteStreamFetcher: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    
    private var _session: URLSession?
    private var _task: URLSessionDataTask?
    private var _responseContinuation: CheckedContinuation<(URLResponse, AsyncThrowingStream<UInt8, Error>), Error>?
    private var _streamContinuation: AsyncThrowingStream<UInt8, Error>.Continuation?
    private var _byteStream: AsyncThrowingStream<UInt8, Error>?
    private var _isCleanedUp = false
    
    // Batch buffer for performance optimization
    private var _batchBuffer = Data()
    private let batchSize = 8192  // 8KB batch size for yield
    
    init(configuration: URLSessionConfiguration) {
        self.configuration = configuration
    }
    
    func start(url: URL) async throws -> (URLResponse, AsyncThrowingStream<UInt8, Error>) {
        return try await withCheckedThrowingContinuation { continuation in
            let stream = AsyncThrowingStream<UInt8, Error> { streamContinuation in
                self.lock.lock()
                self._streamContinuation = streamContinuation
                self._byteStream = stream
                self._responseContinuation = continuation
                
                let session = URLSession(configuration: self.configuration, delegate: self, delegateQueue: nil)
                let task = session.dataTask(with: url)
                
                self._session = session
                self._task = task
                self.lock.unlock()
                
                task.resume()
                
                streamContinuation.onTermination = { @Sendable [weak self] _ in
                    self?.cleanup()
                }
            }
        }
    }
    
    // MARK: - URLSessionDataDelegate
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        lock.lock()
        let responseCont = _responseContinuation
        let byteStream = _byteStream
        _responseContinuation = nil
        lock.unlock()
        
        if let stream = byteStream {
            responseCont?.resume(returning: (response, stream))
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !data.isEmpty else { return }
        
        lock.lock()
        let continuation = _streamContinuation
        
        // Append to batch buffer
        _batchBuffer.append(data)
        
        // Yield in batches for better performance
        while _batchBuffer.count >= batchSize {
            let batch = _batchBuffer.prefix(batchSize)
            _batchBuffer.removeFirst(batchSize)
            lock.unlock()
            
            // Yield batch outside of lock
            for byte in batch {
                continuation?.yield(byte)
            }
            
            lock.lock()
        }
        lock.unlock()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let streamCont = _streamContinuation
        let responseCont = _responseContinuation
        let remainingData = _batchBuffer
        _batchBuffer.removeAll()
        lock.unlock()
        
        // Flush remaining buffered data before finishing
        if !remainingData.isEmpty && error == nil {
            for byte in remainingData {
                streamCont?.yield(byte)
            }
        }
        
        if let error {
            streamCont?.finish(throwing: error)
            responseCont?.resume(throwing: error)
        } else {
            streamCont?.finish()
        }
        cleanup()
    }
    
    private func cleanup() {
        lock.lock()
        guard !_isCleanedUp else {
            lock.unlock()
            return
        }
        _isCleanedUp = true
        
        _streamContinuation = nil
        _responseContinuation = nil
        _byteStream = nil
        _batchBuffer.removeAll()
        
        let task = _task
        let session = _session
        _task = nil
        _session = nil
        lock.unlock()
        
        task?.cancel()
        session?.invalidateAndCancel()
    }
}

#endif

