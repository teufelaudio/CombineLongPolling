import Combine
import Foundation
import NetworkExtensions

extension RESTClient where Session: LongPollingSessionProtocol {
    public func longPollingRequest<Body, Value, Endpoint: RESTEndpoint>(
        endpoint: Endpoint,
        requestParser: RequestParser<Body> = .ignore,
        responseParser: ResponseParser<Value>
    ) -> AnyPublisher<Value, Error> where Body == Endpoint.Body {
        let statusCodeHandler = endpoint.statusCodeHandler ?? self.statusCodeHandler ?? .default
        let scopedSession = session

        return createURLRequest(endpoint: endpoint, requestParser: requestParser)
            .promise
            .map { urlRequest in
                scopedSession
                    .longPollingPublisher(for: urlRequest)
                    .mapError { $0 as Error }
            }
            .switchToLatest()
            .flatMap { taskResult -> Promise<(Data, HTTPURLResponse), Error> in
                let (data, response) = taskResult
                return statusCodeHandler
                    .eval(response as? HTTPURLResponse)
                    .map { httpResponse in
                        return (data, httpResponse)
                    }
                    .promise
            }
            .flatMap { data, httpResponse -> Promise<Value, Error> in
                responseParser.parse(data, httpResponse).promise
            }
            .eraseToAnyPublisher()
    }
}
