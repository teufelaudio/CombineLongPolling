import Combine
import Foundation

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension URLSession: LongPollingSessionProtocol {
    /// Returns a publisher that wraps a URL session data task for a given URL in a long-polling mechanism that will
    /// keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter url: The URL for which to create a long-polling task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL.
    public func longPollingPublisher(for url: URL) -> LongPollingPublisher {
        longPollingPublisher(for: self.dataTaskPublisher(for: url))
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter request: The URL request for which to create a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL request.
    public func longPollingPublisher(for request: URLRequest) -> LongPollingPublisher {
        longPollingPublisher(for: self.dataTaskPublisher(for: request))
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter dataTaskPublisher: The upstream data task that will be wrapped in a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the provided upstream data task.
    public func longPollingPublisher<P: Publisher>(for dataTaskPublisher: P) -> LongPollingPublisher
    where P.Output == (data: Data, response: URLResponse), P.Failure == URLError {
        LongPollingPublisher(dataTaskPublisher: dataTaskPublisher)
    }

    public var timeoutIntervalForRequest: TimeInterval {
        configuration.timeoutIntervalForRequest
    }

    public var timeoutIntervalForResource: TimeInterval {
        configuration.timeoutIntervalForResource
    }
}

#if DEBUG
public class LongPollingSessionMock {
    public init() { }

    public var longPollingPassthrough = PassthroughSubject<(data: Data, response: URLResponse), URLError>()

    public lazy var longPollingPassthroughURL: (URL) -> LongPollingPublisher = { _ in
        LongPollingPublisher(dataTaskPublisher: self.longPollingPassthrough)
    }
    public lazy var longPollingPassthroughURLRequest: (URLRequest) -> LongPollingPublisher = { _ in
        LongPollingPublisher(dataTaskPublisher: self.longPollingPassthrough)
    }
    public lazy var longPollingPassthroughFromPublisher: (AnyPublisher<(data: Data, response: URLResponse), URLError>) -> LongPollingPublisher = { p in
        LongPollingPublisher(dataTaskPublisher: p)
    }

    public func serverSendsLongPollingSuccess(
        data: Data = Data(),
        response: URLResponse = HTTPURLResponse(url: URL(string: "https://127.0.0.1")!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
        completes: Bool = false
    ) {
        longPollingPassthrough.send((data: data, response: response))
        if completes { longPollingPassthrough.send(completion: .finished) }
    }

    public func serverSendsLongPollingFailure(_ error: URLError) {
        longPollingPassthrough.send(completion: .failure(error))
    }
}

/// Conformance to LongPollingSessionProtocol
extension LongPollingSessionMock {
    public func longPollingPublisher(for url: URL) -> LongPollingPublisher {
        longPollingPassthroughURL(url)
    }

    public func longPollingPublisher(for request: URLRequest) -> LongPollingPublisher {
        longPollingPassthroughURLRequest(request)
    }

    public func longPollingPublisher<P>(for dataTaskPublisher: P) -> LongPollingPublisher
    where P: Publisher, P.Failure == URLError, P.Output == (data: Data, response: URLResponse) {
        longPollingPassthroughFromPublisher(dataTaskPublisher.eraseToAnyPublisher())
    }
}
#endif
