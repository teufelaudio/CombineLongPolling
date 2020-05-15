//
//  LongPollingPublisher.swift
//  CombineExtensions
//
//  Created by Luiz Barbosa on 29.10.19.
//  Copyright © 2020 Lautsprecher Teufel GmbH. All rights reserved.
//

import Combine
import Foundation

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension URLSession {

    /// Returns a publisher that wraps a URL session data task for a given URL in a long-polling mechanism that will
    /// keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter url: The URL for which to create a long-polling task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL.
    public func longPollingPublisher(for url: URL) -> URLSession.LongPollingPublisher {
        longPollingPublisher(for: self.dataTaskPublisher(for: url))
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter request: The URL request for which to create a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the URL request.
    public func longPollingPublisher(for request: URLRequest) -> URLSession.LongPollingPublisher {
        longPollingPublisher(for: self.dataTaskPublisher(for: request))
    }

    /// Returns a publisher that wraps a URL session data task for a given URL request in a long-polling mechanism that
    /// will keep recreating that data task every time it ends, either with an error or a success.
    ///
    /// The publisher publishes the resulting output every time the internal data task completes, with either a success
    /// or a failure. This publisher is never expected to fail or complete, unless it's destroyed.
    /// - Parameter dataTaskPublisher: The upstream data task that will be wrapped in a long-polling data task.
    /// - Returns: A publisher that wraps a long-polling data task for the provided upstream data task.
    public func longPollingPublisher(for dataTaskPublisher: DataTaskPublisher) -> URLSession.LongPollingPublisher {
        LongPollingPublisher(upstream: dataTaskPublisher)
    }

    /// Represents a Combine publisher that starts a data task that, once finished, will be restarted over and over
    /// again. The data task can terminate due to error or timeout, but this won't be propagated as error to the
    /// LongPollingPublisher, because that would interrupt the main publisher. Instead, this publisher will emit events
    /// of type `Result<(Data, URLResponse), Error>` for every time a `DataTaskPublisher ` emits a successful output
    /// or an error. Then, the `LongPollingPublisher` restarts the `DataTaskPublisher`.
    /// `LongPollingPublisher` will `Never` fail.
    public struct LongPollingPublisher: Publisher {
        /// The kind of values published by this publisher.
        public typealias Output = Result<(Data, URLResponse), URLError>

        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = Never

        public let upstream: URLSession.DataTaskPublisher

        /// Creates a new `LongPollingPublisher` from an upstream `DataTaskPublisher`
        /// - Parameter upstream: the `DataTaskPublisher` containing the `URLRequest`
        public init(upstream: URLSession.DataTaskPublisher) {
            self.upstream = upstream
        }

        /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Failure, S.Input == Output {
            start().subscribe(subscriber)
        }

        private func start() -> AnyPublisher<Output, Never> {
            upstream
                .map(Result<(Data, URLResponse), URLError>.success)
                .catch { error in
                    Just(.failure(error))
                }
                .assertNoFailure()
                .flatMap(maxPublishers: .max(1)) { event in
                    self.start().prepend(event)
                }
                .eraseToAnyPublisher()
        }
    }
}
