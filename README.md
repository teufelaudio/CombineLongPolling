# Combine HTTP Long-Polling wrappers

This library implements basic HTTP Long-Polling functionality using Combine.

## Long-polling Publisher

Represents a Combine publisher that starts a data task that, once finished, will be restarted over and over again. The data task can terminate due to error or timeout, but this won't be propagated as error to the LongPollingPublisher, because that would interrupt the main publisher. Instead, this publisher will emit events of type `Result<(Data, URLResponse), Error>` for every time a `DataTaskPublisher ` emits a successful output or an error. Then, the `LongPollingPublisher` restarts the `DataTaskPublisher`.
`LongPollingPublisher` will `Never` fail.

## Usage:

```swift
let config = URLSessionConfiguration.default
// For long-polling you probably want big numbers in here
// but for testing how it works, start with short times
config.timeoutIntervalForRequest = 10
config.timeoutIntervalForResource = 10

// Create and keep your data task (`AnyCancellable`)
let task = URLSession(configuration: config)
    .longPollingPublisher(for: URL(string: "http://localhost:3000/subscribe")!)
    .map { result in
        // You may want to convert URLResponse into HTTPURLResponse first
        // and validate your statusCode first, and also decode the JSON
        // from the data variable, but for simplicity here we only check
        // how the main data task ended, with success or failure. It will
        // be restarted after that, so LongPollingPublisher will keep
        // emitting values forever, and never fails.
        switch result {
        case let .success(data, _):
            return String(data: data, encoding: .utf8)!
        case let .failure(error):
            return String("catching error: \(error)")
        }
    }
    .sink { string in Swift.print(string) }
```

## Installation:

```swift
.package(url: "https://github.com/teufelaudio/CombineLongPolling.git", .branch("master"))
```
