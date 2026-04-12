import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fake

final class FakeHTTPClient: HTTPClientProviding, @unchecked Sendable {
    var result: (any Sendable)?
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
        return result as! Response
    }
}

// MARK: - Helper

private func makeResult(
    pairId: String = "sleep_hrv",
    lagHours: Int = 36,
    r: Double = 0.71,
    pValue: Double = 0.003,
    n: Int = 52,
    effectSize: Double = 0.18,
    confidence: CorrelationResult.Confidence = .high
) -> CorrelationResult {
    CorrelationResult(
        pairId: pairId,
        lagHours: lagHours,
        r: r,
        pValue: pValue,
        n: n,
        effectSize: effectSize,
        confidence: confidence,
        computedAt: Date()
    )
}

private func makeIsolatedCache() -> CacheActor {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("healthtrackr_tests_\(UUID().uuidString)", isDirectory: true)
    return CacheActor(directory: dir)
}

// MARK: - Narrate Logic Tests

@Suite("PatternNarrator")
struct PatternNarratorTests {
    @Test("narrate returns empty for empty results")
    func emptyResults() async {
        let narrator = PatternNarrator(httpClient: FakeHTTPClient(), cache: makeIsolatedCache())
        let narrations = await narrator.narrate(results: [])
        #expect(narrations.isEmpty)
    }

    @Test("narrate filters out hidden and emerging results")
    func filtersLowConfidence() async {
        let narrator = PatternNarrator(httpClient: FakeHTTPClient(), cache: makeIsolatedCache())
        let results = [
            makeResult(confidence: .hidden),
            makeResult(confidence: .emerging),
        ]
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.isEmpty)
    }

    @Test("narrate processes high confidence results")
    func processesHighConfidence() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.result = AnthropicMessageResponse(
            content: [.init(type: "text", text: "Test Headline\nTest body.")]
        )
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "sleep_hrv")
    }

    @Test("narrate processes medium confidence results")
    func processesMediumConfidence() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.result = AnthropicMessageResponse(
            content: [.init(type: "text", text: "Headline\nBody text.")]
        )
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "steps_rhr", confidence: .medium)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "steps_rhr")
    }

    @Test("narrate limits batch to maxBatchSize")
    func limitsBatchSize() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.result = AnthropicMessageResponse(
            content: [.init(type: "text", text: "H\nB")]
        )
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
    func fallbackWithoutAPIKey() async {
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
    func usesKeychainAPIKey() async {
        let testKey = "sk-ant-test-key-\(UUID().uuidString)"
        KeychainHelper.save(key: PatternNarrator.keychainKey, data: Data(testKey.utf8))
        defer { KeychainHelper.delete(key: PatternNarrator.keychainKey) }

        let fakeClient = FakeHTTPClient()
        fakeClient.result = AnthropicMessageResponse(
            content: [.init(type: "text", text: "Headline\nBody text.")]
        )
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        _ = await narrator.narrate(results: results)

        #expect(fakeClient.lastRequest?.value(forHTTPHeaderField: "x-api-key") == testKey)
    }

    @Test("returns fallback when HTTP client throws")
    func fallbackOnNetworkError() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.errorToThrow = NetworkError.httpError(statusCode: 500, body: "Internal Server Error")
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.body.contains("Couldn't generate explanation") == true)
    }

    @Test("returns parsed narration on successful response")
    func parsedNarrationOnSuccess() async {
        let fakeClient = FakeHTTPClient()
        fakeClient.result = AnthropicMessageResponse(
            content: [.init(type: "text", text: "Sleep Boosts HRV\nMore sleep means better recovery.")]
        )
        let narrator = PatternNarrator(httpClient: fakeClient, cache: makeIsolatedCache())
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.headline == "Sleep Boosts HRV")
        #expect(narrations.first?.body == "More sleep means better recovery.")
    }
}
