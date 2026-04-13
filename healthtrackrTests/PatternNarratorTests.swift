import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fake

@MainActor
final class FakeHTTPClient: HTTPClientProviding {
    var respondWith: ((URLRequest) throws -> Data)?
    var errorToThrow: Error?
    var lastRequest: URLRequest?

    func send<Response: Decodable & Sendable>(
        request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        lastRequest = request
        if let error = errorToThrow {
            throw error
        }
        guard let responder = respondWith else {
            throw FakeHTTPClientError.noResponder
        }
        let data = try responder(request)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    enum FakeHTTPClientError: Error { case noResponder }
}

// MARK: - Helper

private func makeAnthropicResponder(text: String) -> (URLRequest) throws -> Data {
    return { _ in
        let response = AnthropicMessageResponse(
            content: [.init(type: "text", text: text)]
        )
        return try JSONEncoder().encode(response)
    }
}

// MARK: - Narrate Logic Tests

@Suite("PatternNarrator")
struct PatternNarratorTests {
    @Test("narrate returns empty for empty results")
    @MainActor func emptyResults() async {
        let narrator = PatternNarrator(httpClient: FakeHTTPClient(), cache: makeIsolatedCache())
        let narrations = await narrator.narrate(results: [])
        #expect(narrations.isEmpty)
    }

    @Test("narrate filters out hidden and emerging results")
    @MainActor func filtersLowConfidence() async {
        let narrator = PatternNarrator(httpClient: FakeHTTPClient(), cache: makeIsolatedCache())
        let results = [
            makeResult(confidence: .hidden),
            makeResult(confidence: .emerging),
        ]
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.isEmpty)
    }

    @Test("narrate processes high confidence results")
    @MainActor func processesHighConfidence() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.respondWith = makeAnthropicResponder(text: "Test Headline\nTest body.")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "sleep_hrv")
    }

    @Test("narrate processes medium confidence results")
    @MainActor func processesMediumConfidence() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.respondWith = makeAnthropicResponder(text: "Headline\nBody text.")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "steps_rhr", confidence: .medium)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "steps_rhr")
    }

    @Test("narrate limits batch to maxBatchSize")
    @MainActor func limitsBatchSize() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.respondWith = makeAnthropicResponder(text: "H\nB")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = (0..<10).map { i in
            makeResult(pairId: "pair_\(i)", lagHours: i, confidence: .high)
        }
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.count <= 5)
    }
}

// MARK: - HTTP Client Integration Tests

@Suite("PatternNarrator.fetchNarration")
struct PatternNarratorFetchTests {
    @Test("returns fallback when no API key in Keychain")
    @MainActor func fallbackWithoutAPIKey() async {
        // Ensure no key is present
        KeychainHelper.delete(key: PatternNarrator.keychainKey)
        let fakeClient = FakeHTTPClient()
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.headline == "Sleep duration and next-day HRV")
        #expect(narrations.first?.body.contains("Couldn't generate explanation") == true)
        #expect(fakeClient.lastRequest == nil)
    }

    @Test("reads API key from Keychain and sends it in request header")
    @MainActor func usesKeychainAPIKey() async {
        let testKey = "sk-ant-test-key-\(UUID().uuidString)"
        KeychainHelper.save(key: PatternNarrator.keychainKey, data: Data(testKey.utf8))
        defer { KeychainHelper.delete(key: PatternNarrator.keychainKey) }

        let fakeClient = FakeHTTPClient()
        fakeClient.respondWith = makeAnthropicResponder(text: "Headline\nBody text.")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        _ = await narrator.narrate(results: results)

        #expect(fakeClient.lastRequest?.value(forHTTPHeaderField: "x-api-key") == testKey)
    }

    @Test("returns fallback when HTTP client throws")
    @MainActor func fallbackOnNetworkError() async {
        // We need a keychain key present so the narrator actually tries to call the API
        let testKey = "sk-ant-test-key-\(UUID().uuidString)"
        KeychainHelper.save(key: PatternNarrator.keychainKey, data: Data(testKey.utf8))
        defer { KeychainHelper.delete(key: PatternNarrator.keychainKey) }

        let fakeClient = FakeHTTPClient()
        fakeClient.errorToThrow = NetworkError.httpError(statusCode: 500, body: "Internal Server Error")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.body.contains("Couldn't generate explanation") == true)
    }

    @Test("returns parsed narration on successful response")
    @MainActor func parsedNarrationOnSuccess() async {
        let testKey = "sk-ant-test-key-\(UUID().uuidString)"
        KeychainHelper.save(key: PatternNarrator.keychainKey, data: Data(testKey.utf8))
        defer { KeychainHelper.delete(key: PatternNarrator.keychainKey) }

        let fakeClient = FakeHTTPClient()
        fakeClient.respondWith = makeAnthropicResponder(text: "Sleep Boosts HRV\nMore sleep means better recovery.")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.headline == "Sleep Boosts HRV")
        #expect(narrations.first?.body == "More sleep means better recovery.")
    }
}
