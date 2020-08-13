import Combine
import Foundation

public protocol LongPollingSessionProtocol {
    /// Returns a publisher that wraps a URL session data task for a given URL in a long-polling mechanism that will
    /// keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter url: The URL for which to create a long-polling task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL.
    func longPollingPublisher(for url: URL) -> LongPollingPublisher

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter request: The URL request for which to create a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL request.
    func longPollingPublisher(for request: URLRequest) -> LongPollingPublisher

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter dataTaskPublisher: The upstream data task that will be wrapped in a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the provided upstream data task.
    func longPollingPublisher<P: Publisher>(for dataTaskPublisher: P) -> LongPollingPublisher
    where P.Output == (data: Data, response: URLResponse), P.Failure == URLError
}
