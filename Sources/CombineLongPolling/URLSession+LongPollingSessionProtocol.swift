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
}
