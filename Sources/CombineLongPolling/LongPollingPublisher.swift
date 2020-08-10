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
    public typealias Output = Result<(Data, URLResponse), URLError>

    /// The kind of errors this publisher might publish.
    ///
    /// Use `Never` if this `Publisher` does not publish errors.
    public typealias Failure = Never

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
                        .map(Result<(Data, URLResponse), URLError>.success)
                        .catch { error in
                            Just(.failure(error))
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
                        .setFailureType(to: Never.self)
                        .sink { result in
                            _ = self.buffer?.buffer(value: result )
                        }
                }
            }
        }
    }
}
