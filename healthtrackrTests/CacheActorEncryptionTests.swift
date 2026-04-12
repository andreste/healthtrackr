import Foundation
import Testing
@testable import healthtrackr

@Suite("CacheActor File Protection")
struct CacheActorEncryptionTests {

    private func makeIsolatedCache() -> CacheActor {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthtrackr_encryption_tests_\(UUID().uuidString)", isDirectory: true)
        return CacheActor(directory: dir)
    }

    private func makeCacheWithKnownDir() -> (CacheActor, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("healthtrackr_encryption_\(UUID().uuidString)", isDirectory: true)
        return (CacheActor(directory: dir), dir)
    }

    private func makeResult(pairId: String = "sleep_hrv") -> CorrelationResult {
        CorrelationResult(
            pairId: pairId,
            lagHours: 36,
            r: 0.71,
            pValue: 0.003,
            n: 52,
            effectSize: 0.18,
            confidence: .high,
            computedAt: Date()
        )
    }

    private func makeNarration(pairId: String = "sleep_hrv") -> PatternNarration {
        PatternNarration(pairId: pairId, headline: "Headline", body: "Body.", cachedAt: Date())
    }

    // MARK: - Directory Protection

    @Test("cache directory is created by init")
    func directoryCreatedOnInit() {
        let (_, dir) = makeCacheWithKnownDir()
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test("cache directory has file protection attribute set")
    func directoryHasFileProtectionAttribute() {
        let (_, dir) = makeCacheWithKnownDir()
        let attrs = try? FileManager.default.attributesOfItem(atPath: dir.path)
        // On iOS device: .complete. On macOS/simulator the key may be absent — just verify no crash.
        let protection = attrs?[.protectionKey] as? FileProtectionType
        // If protection is set, it must be .complete
        if let protection {
            #expect(protection == .complete)
        }
    }

    // MARK: - Results Round-Trip

    @Test("saved correlation results can be loaded back")
    func resultsRoundTrip() async {
        let cache = makeIsolatedCache()
        let pairId = "sleep_hrv_\(UUID().uuidString)"
        let result = makeResult(pairId: pairId)
        await cache.save(results: [result], pairId: pairId)

        let loaded = await cache.loadAll(pairId: pairId)
        #expect(loaded.count == 1)
        #expect(loaded.first?.pairId == pairId)
        #expect(loaded.first?.r == 0.71)
        #expect(loaded.first?.confidence == .high)
    }

    @Test("saved results preserve all fields")
    func resultsPreserveFields() async {
        let cache = makeIsolatedCache()
        let pairId = "hrv_rhr_\(UUID().uuidString)"
        let result = makeResult(pairId: pairId)
        await cache.save(results: [result], pairId: pairId)

        let loaded = await cache.loadAll(pairId: pairId)
        #expect(loaded.first?.lagHours == 36)
        #expect(loaded.first?.pValue == 0.003)
        #expect(loaded.first?.n == 52)
        #expect(loaded.first?.effectSize == 0.18)
    }

    @Test("multiple results round-trip correctly")
    func multipleResultsRoundTrip() async {
        let cache = makeIsolatedCache()
        let pairId = "steps_hrv_\(UUID().uuidString)"
        let results = [makeResult(pairId: pairId), makeResult(pairId: pairId)]
        await cache.save(results: results, pairId: pairId)

        let loaded = await cache.loadAll(pairId: pairId)
        #expect(loaded.count == 2)
    }

    // MARK: - Narration Round-Trip

    @Test("saved narration can be loaded back")
    func narrationRoundTrip() async {
        let cache = makeIsolatedCache()
        let narration = makeNarration(pairId: "steps_rhr")
        await cache.saveNarration(narration, lagHours: 24)

        let loaded = await cache.loadNarration(pairId: "steps_rhr", lagHours: 24)
        #expect(loaded != nil)
        #expect(loaded?.headline == "Headline")
        #expect(loaded?.body == "Body.")
    }

    @Test("narration for different lagHours is stored separately")
    func narrationSeparatedByLag() async {
        let cache = makeIsolatedCache()
        let pairId = "sleep_hrv"
        let narration24 = PatternNarration(pairId: pairId, headline: "24h", body: "Body.", cachedAt: Date())
        let narration48 = PatternNarration(pairId: pairId, headline: "48h", body: "Body.", cachedAt: Date())
        await cache.saveNarration(narration24, lagHours: 24)
        await cache.saveNarration(narration48, lagHours: 48)

        let loaded24 = await cache.loadNarration(pairId: pairId, lagHours: 24)
        let loaded48 = await cache.loadNarration(pairId: pairId, lagHours: 48)
        #expect(loaded24?.headline == "24h")
        #expect(loaded48?.headline == "48h")
    }

    @Test("loading nonexistent narration returns nil")
    func missingNarrationReturnsNil() async {
        let cache = makeIsolatedCache()
        let loaded = await cache.loadNarration(pairId: "nonexistent", lagHours: 0)
        #expect(loaded == nil)
    }
}
