import Foundation
import Testing
@testable import healthtrackr

// MARK: - URLProtocol Stub

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responseProvider: ((URLRequest) -> (Data?, URLResponse?, Error?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (data, response, error) = Self.responseProvider?(request) ?? (nil, nil, nil)

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubSession(
    data: Data? = nil,
    statusCode: Int = 200,
    error: Error? = nil
) -> URLSession {
    let url = URL(string: "https://example.com")!
    StubURLProtocol.responseProvider = { _ in
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        return (data, response, error)
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

private struct TestResponse: Decodable, Equatable, Sendable {
    let message: String
}

// MARK: - Tests

@Suite("HTTPClient", .serialized)
struct HTTPClientTests {
    @Test("decodes valid JSON response")
    func decodesValidResponse() async throws {
        let session = stubSession(data: #"{"message":"hello"}"#.data(using: .utf8), statusCode: 200)
        let client = HTTPClient(session: session)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let result = try await client.send(request: request, responseType: TestResponse.self)
        #expect(result == TestResponse(message: "hello"))
    }

    @Test("throws httpError for 400 status")
    func throwsOnBadRequest() async {
        let session = stubSession(data: "Bad Request".data(using: .utf8), statusCode: 400)
        let client = HTTPClient(session: session)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await client.send(request: request, responseType: TestResponse.self)
            Issue.record("Expected NetworkError.httpError")
        } catch let error as NetworkError {
            #expect(error == .httpError(statusCode: 400, body: "Bad Request"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("throws httpError for 500 status")
    func throwsOnServerError() async {
        let session = stubSession(data: "Internal Server Error".data(using: .utf8), statusCode: 500)
        let client = HTTPClient(session: session)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await client.send(request: request, responseType: TestResponse.self)
            Issue.record("Expected NetworkError.httpError")
        } catch let error as NetworkError {
            #expect(error == .httpError(statusCode: 500, body: "Internal Server Error"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("throws decodingFailed for malformed JSON")
    func throwsOnMalformedJSON() async {
        let session = stubSession(data: "not json".data(using: .utf8), statusCode: 200)
        let client = HTTPClient(session: session)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await client.send(request: request, responseType: TestResponse.self)
            Issue.record("Expected NetworkError.decodingFailed")
        } catch let error as NetworkError {
            #expect(error == .decodingFailed(NSError(domain: "", code: 0)))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("accepts 201 status as success")
    func accepts201() async throws {
        let session = stubSession(data: #"{"message":"created"}"#.data(using: .utf8), statusCode: 201)
        let client = HTTPClient(session: session)
        let request = URLRequest(url: URL(string: "https://example.com")!)

        let result = try await client.send(request: request, responseType: TestResponse.self)
        #expect(result == TestResponse(message: "created"))
    }
}

// MARK: - NetworkError Equatable Tests

@Suite("NetworkError")
struct NetworkErrorTests {
    @Test("invalidResponse equals invalidResponse")
    func invalidResponseEquality() {
        #expect(NetworkError.invalidResponse == NetworkError.invalidResponse)
    }

    @Test("httpError equals with same code and body")
    func httpErrorEquality() {
        #expect(NetworkError.httpError(statusCode: 429, body: "rate limited") ==
                NetworkError.httpError(statusCode: 429, body: "rate limited"))
    }

    @Test("httpError differs with different status code")
    func httpErrorDifferentCode() {
        #expect(NetworkError.httpError(statusCode: 400, body: nil) !=
                NetworkError.httpError(statusCode: 500, body: nil))
    }

    @Test("decodingFailed equals decodingFailed")
    func decodingFailedEquality() {
        let e1 = NetworkError.decodingFailed(NSError(domain: "a", code: 1))
        let e2 = NetworkError.decodingFailed(NSError(domain: "b", code: 2))
        #expect(e1 == e2)
    }

    @Test("different cases are not equal")
    func differentCasesNotEqual() {
        #expect(NetworkError.invalidResponse != NetworkError.httpError(statusCode: 400, body: nil))
    }
}
