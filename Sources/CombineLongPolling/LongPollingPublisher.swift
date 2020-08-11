import Combine
import Foundation

/// Represents a Combine publisher that starts a data task that, once finished, will be restarted over and over
/// again. The data task can terminate due to error or timeout, but this won't be propagated as error to the
/// LongPollingPublisher, because that would interrupt the main publisher. Instead, this publisher will emit events
/// of type `Result<(Data, URLResponse), Error>` for every time a `DataTaskPublisher ` emits a successful output
/// or an error. Then, the `LongPollingPublisher` restarts the `DataTaskPublisher`.
/// `LongPollingPublisher` will `Never` fail.
public struct LongPollingPublisher: Publisher {
    /// The kind of values published by this publisher.
    public typealias Output = (Data, URLResponse)

    /// The kind of errors this publisher might publish.
    /// This publisher will forward any `URLError` coming from upstream, except URLError.timedOut (Code -1001) which
    /// is expected to happen on long polling and will restart the polling
    public typealias Failure = URLError

    public let dataTaskPublisher: AnyPublisher<(data: Data, response: URLResponse), URLError>

    /// Creates a new `LongPollingPublisher` from an upstream `DataTaskPublisher`
    /// - Parameter upstream: the `DataTaskPublisher` containing the `URLRequest`
    public init<P: Publisher>(dataTaskPublisher: P) where P.Output == (data: Data, response: URLResponse), P.Failure == URLError {
        self.dataTaskPublisher = dataTaskPublisher.eraseToAnyPublisher()
    }

    /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
        let subscription = Subscription(dataTaskPublisher: dataTaskPublisher, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

extension LongPollingPublisher {
    class Subscription<S: Subscriber>: Combine.Subscription where S.Input == Output, S.Failure == Failure {
        private var buffer: DemandBuffer<S>?
        let dataTaskPublisher: AnyPublisher<(data: Data, response: URLResponse), URLError>
        private let lock = NSRecursiveLock()
        private var started = false
        private var currentRequest: AnyCancellable?
        private var semaphore = DispatchSemaphore(value: 1)

        init(dataTaskPublisher: AnyPublisher<(data: Data, response: URLResponse), URLError>, subscriber: S) {
            self.dataTaskPublisher = dataTaskPublisher
            self.buffer = DemandBuffer(subscriber: subscriber)
        }

        func request(_ demand: Subscribers.Demand) {
            guard let buffer = self.buffer else { return }

            lock.lock()

            if !started && demand > .none {
                // There's demand, and it's the first demanded value, so we start polling
                started = true
                lock.unlock()

                start()
            } else {
                lock.unlock()
            }

            // Flush buffer
            // If subscriber asked for 10 but we had only 3 in the buffer, it will return 7 representing the remaining demand
            // We actually don't care about that number, as once we buffer more items they will be flushed right away, so simply ignore it
            _ = buffer.demand(demand)
        }

        public func cancel() {
            buffer?.complete(completion: .finished)
            started = false
            currentRequest = nil
            buffer = nil
            self.semaphore = DispatchSemaphore(value: 1)
        }

        private func start() {
            self.semaphore = DispatchSemaphore(value: 1)
            startPolling()
        }

        private func startPolling() {
            DispatchQueue.global(qos: .utility).async {
                while(self.started) {
                    self.semaphore.wait()

                    self.currentRequest = self.dataTaskPublisher
                        .catch { error -> AnyPublisher<(data: Data, response: URLResponse), URLError> in
                            // Timeout errors are accepted as valid. In Long Polling terms that means that there's no output during the
                            // time we were observing. So in that case we send an Empty publisher that completes automatically, forcing a
                            // new long poll data task to start in the loop.
                            if error.code == URLError.Code.timedOut {
                                return Empty(completeImmediately: true).eraseToAnyPublisher()
                            }
                            // Any other error will kill the subscription
                            return Fail(error: error).eraseToAnyPublisher()
                        }
                        .handleEvents(
                            receiveCompletion: { [weak self] _ in
                                guard let self = self else { return }
                                self.semaphore.signal()
                            },
                            receiveCancel: { [weak self] in
                                guard let self = self else { return }
                                self.semaphore.signal()
                            }
                        )
                        .sink(
                            receiveCompletion: { [weak self] completion in
                                guard let self = self else { return }

                                guard case let .failure(error) = completion else {
                                    // If this completes without error, we don't send completion to downstream, because the Long Polling will
                                    // restart. Only error will stop the subscription and send a kill message to downstream.
                                    return
                                }

                                self.started = false
                                _ = self.buffer?.complete(completion: .failure(error))
                                self.buffer = nil
                                self.semaphore = DispatchSemaphore(value: 1)
                            },
                            receiveValue: { [weak self] result in
                                guard let self = self else { return }

                                _ = self.buffer?.buffer(value: result)
                            }
                        )
                }
            }
        }
    }
}
