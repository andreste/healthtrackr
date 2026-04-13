import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeNarration(
    pairId: String = "sleep_hrv",
    headline: String = "Sleep Boosts HRV",
    body: String = "More sleep improves recovery.",
    cachedAt: Date = Date()
) -> PatternNarration {
    PatternNarration(pairId: pairId, headline: headline, body: body, cachedAt: cachedAt)
}

// MARK: - CacheActor Narration Tests

@Suite("CacheActor Narration Freshness")
struct CacheActorNarrationTests {
    @Test("isNarrationFresh returns false when no cache exists")
    func freshReturnsFalseWhenEmpty() async {
        let cache = makeIsolatedCache()
        let fresh = await cache.isNarrationFresh(pairId: "nonexistent_pair", lagHours: 0)
        #expect(!fresh)
    }

    @Test("isNarrationFresh returns true when narration cached today")
    func freshReturnsTrueForToday() async {
        let cache = makeIsolatedCache()
        let narration = makeNarration(pairId: "sleep_hrv", cachedAt: Date())
        await cache.saveNarration(narration, lagHours: 12)

        let fresh = await cache.isNarrationFresh(pairId: "sleep_hrv", lagHours: 12)
        #expect(fresh)
    }

    @Test("isNarrationFresh returns false when narration cached yesterday")
    func freshReturnsFalseForYesterday() async {
        let cache = makeIsolatedCache()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let narration = makeNarration(pairId: "sleep_hrv", cachedAt: yesterday)
        await cache.saveNarration(narration, lagHours: 12)

        let fresh = await cache.isNarrationFresh(pairId: "sleep_hrv", lagHours: 12)
        #expect(!fresh)
    }

    @Test("saveNarration and loadNarration use consistent lagHours key")
    func saveLoadConsistency() async {
        let cache = makeIsolatedCache()
        let narration = makeNarration(pairId: "steps_rhr")
        await cache.saveNarration(narration, lagHours: 24)

        let loaded = await cache.loadNarration(pairId: "steps_rhr", lagHours: 24)
        #expect(loaded != nil)
        #expect(loaded?.headline == "Sleep Boosts HRV")

        // Different lagHours should not find it
        let notFound = await cache.loadNarration(pairId: "steps_rhr", lagHours: 0)
        #expect(notFound == nil)
    }
}

// MARK: - CacheActor Clear Tests

@Suite("CacheActor.clearAllCaches")
struct CacheActorClearTests {
    @Test("clearAllCaches removes cached narration files")
    func clearAllCachesRemovesNarrationFiles() async {
        let cache = makeIsolatedCache()
        let narration = makeNarration(pairId: "sleep_hrv")
        await cache.saveNarration(narration, lagHours: 12)

        await cache.clearAllCaches()

        let loaded = await cache.loadNarration(pairId: "sleep_hrv", lagHours: 12)
        #expect(loaded == nil)
    }

    @Test("clearAllCaches removes UserDefaults timestamp keys")
    func clearAllCachesRemovesTimestamps() async {
        let pairId = "test_clear_\(UUID().uuidString)"
        let cache = makeIsolatedCache()
        let result = makeResult(pairId: pairId)
        await cache.save(results: [result], pairId: pairId)

        let staleBeforeClear = await cache.isStale(pairId: pairId)
        #expect(!staleBeforeClear)

        await cache.clearAllCaches()

        let staleAfterClear = await cache.isStale(pairId: pairId)
        #expect(staleAfterClear)
    }

    @Test("clearAllCaches removes all results files")
    func clearAllCachesRemovesResultFiles() async {
        let pairId = "steps_rhr"
        let cache = makeIsolatedCache()
        let result = makeResult(pairId: pairId)
        await cache.save(results: [result], pairId: pairId)

        await cache.clearAllCaches()

        let loaded = await cache.loadAll(pairId: pairId)
        #expect(loaded.isEmpty)
    }
}

// MARK: - PatternNarrator Caching Integration Tests

@Suite("PatternNarrator Daily Caching")
struct PatternNarratorCachingTests {
    @Test("returns cached narration when fresh, does not call API again")
    @MainActor func returnsCachedWhenFresh() async {
        let fakeClient = FakeHTTPClient()
        // No respondWith needed — tests run without an API key so narrator falls back

        let cache = makeIsolatedCache()
        let narrator = PatternNarrator(httpClient: fakeClient, cache: cache)
        let result = makeResult(pairId: "sleep_hrv", lagHours: 36, confidence: .high)

        // First call: no cache, produces a narration (fallback since no API key in tests)
        let firstCall = await narrator.narrate(results: [result])
        #expect(firstCall.count == 1)

        // Second call: should use cache, not call API again
        fakeClient.lastRequest = nil
        let secondCall = await narrator.narrate(results: [result])
        #expect(secondCall.count == 1)
        #expect(secondCall.first?.pairId == "sleep_hrv")
        // No new API call was made (lastRequest stays nil)
        #expect(fakeClient.lastRequest == nil)
    }

    @Test("skips stale cache when narration cached yesterday")
    @MainActor func skipsStaleCache() async {
        let cache = makeIsolatedCache()

        // Seed cache with a stale (yesterday) narration
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let staleNarration = makeNarration(
            pairId: "sleep_hrv",
            headline: "Old Headline",
            body: "Old body.",
            cachedAt: yesterday
        )
        await cache.saveNarration(staleNarration, lagHours: 36)

        // Verify it exists but is not fresh
        let loaded = await cache.loadNarration(pairId: "sleep_hrv", lagHours: 36)
        #expect(loaded != nil)
        let isFresh = await cache.isNarrationFresh(pairId: "sleep_hrv", lagHours: 36)
        #expect(!isFresh)

        // Narrator should skip the stale cache and produce a new narration
        let fakeClient = FakeHTTPClient()
        let narrator = PatternNarrator(httpClient: fakeClient, cache: cache)
        let result = makeResult(pairId: "sleep_hrv", lagHours: 36, confidence: .high)
        let narrations = await narrator.narrate(results: [result])

        #expect(narrations.count == 1)
        // Should be a fresh narration, not the old one
        #expect(narrations.first?.headline != "Old Headline")
    }

    @Test("cache is updated after a fresh API call")
    @MainActor func cacheUpdatedAfterAPICall() async {
        // No respondWith needed — tests run without an API key so narrator falls back
        let fakeClient = FakeHTTPClient()

        let cache = makeIsolatedCache()
        let narrator = PatternNarrator(httpClient: fakeClient, cache: cache)
        let result = makeResult(pairId: "sleep_hrv", lagHours: 24, confidence: .high)

        // First call populates the cache
        let first = await narrator.narrate(results: [result])
        #expect(first.count == 1)

        // Verify cache was written
        let cached = await cache.loadNarration(pairId: "sleep_hrv", lagHours: 24)
        #expect(cached != nil)
        #expect(cached?.headline == first.first?.headline)

        // Second call should return from cache (no new API call)
        fakeClient.lastRequest = nil
        let second = await narrator.narrate(results: [result])
        #expect(second.count == 1)
        #expect(second.first?.headline == first.first?.headline)
        #expect(second.first?.body == first.first?.body)
        #expect(fakeClient.lastRequest == nil)
    }
}
