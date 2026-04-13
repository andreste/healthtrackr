import Foundation
@testable import healthtrackr

// MARK: - Shared test factory helpers

func makeResult(
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

func makeIsolatedCache() -> CacheActor {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("healthtrackr_test_cache_\(UUID().uuidString)", isDirectory: true)
    return CacheActor(directory: dir)
}
