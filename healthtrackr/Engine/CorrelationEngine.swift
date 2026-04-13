import Foundation

@MainActor
final class CorrelationEngine {
    private let cache: any CorrelationCaching

    init(cache: any CorrelationCaching = CacheActor()) {
        self.cache = cache
    }

    static let lagOffsets = [0, 12, 24, 36, 48]

    static let v1Pairs: [(id: String, metricAKey: String, metricBKey: String, shortLabel: String)] = [
        ("sleep_hrv", "sleep", "hrv", "SLEEP + HRV"),
        ("steps_rhr", "steps", "rhr", "STEPS + HR"),
        ("sleep_rhr", "sleep", "rhr", "SLEEP + HR"),
        ("activeEnergy_hrv", "activeEnergy", "hrv", "ENERGY + HRV"),
        ("activeEnergy_rhr", "activeEnergy", "rhr", "ENERGY + HR"),
        ("exerciseTime_rhr", "exerciseTime", "rhr", "EXERCISE + HR"),
        ("exerciseTime_hrv", "exerciseTime", "hrv", "EXERCISE + HRV"),
        ("steps_hrv", "steps", "hrv", "STEPS + HRV"),
        ("vo2Max_rhr", "vo2Max", "rhr", "VO2 MAX + HR"),
        ("distance_rhr", "distance", "rhr", "DISTANCE + HR"),
        ("sleep_walkingHR", "sleep", "walkingHR", "SLEEP + WALKING HR"),
        ("sleep_respiratoryRate", "sleep", "respiratoryRate", "SLEEP + RESP. RATE"),
        ("sleep_spo2", "sleep", "spo2", "SLEEP + BLOOD O₂"),
        ("exerciseTime_walkingHR", "exerciseTime", "walkingHR", "EXERCISE + WALKING HR"),
        ("steps_walkingHR", "steps", "walkingHR", "STEPS + WALKING HR"),
        ("bodyMass_rhr", "bodyMass", "rhr", "BODY MASS + HR"),
        ("bodyMass_vo2Max", "bodyMass", "vo2Max", "BODY MASS + VO2 MAX"),
        ("vo2Max_hrv", "vo2Max", "hrv", "VO2 MAX + HRV"),
        ("vo2Max_walkingHR", "vo2Max", "walkingHR", "VO2 MAX + WALKING HR"),
        ("distance_hrv", "distance", "hrv", "DISTANCE + HRV"),
    ]

    // MARK: - Public

    func cachedResults(for pairId: String) async -> [CorrelationResult] {
        await cache.loadAll(pairId: pairId)
    }

    func run(pairs: [MetricPair]) async {
        for pair in pairs {
            let isStale = await cache.isStale(pairId: pair.id, maxAge: 86400)
            guard isStale else { continue }

            // Run CPU-bound Spearman computation off the main thread.
            let pairId = pair.id
            let metricA = pair.metricA
            let metricB = pair.metricB
            let lagOffsets = Self.lagOffsets

            let results = await Task.detached(priority: .userInitiated) {
                var computed: [CorrelationResult] = []
                for lag in lagOffsets {
                    guard !Task.isCancelled else { return computed }

                    let aligned = MetricAlignment.align(a: metricA, b: metricB, lagHours: lag)
                    guard aligned.count >= 20 else {
                        computed.append(CorrelationResult(
                            pairId: pairId,
                            lagHours: lag,
                            r: 0,
                            pValue: 1,
                            n: aligned.count,
                            effectSize: nil,
                            confidence: .hidden,
                            computedAt: Date()
                        ))
                        continue
                    }

                    let aValues = aligned.map(\.a)
                    let bValues = aligned.map(\.b)

                    let r = StatisticalMath.spearmanR(x: aValues, y: bValues)
                    let n = aligned.count
                    let p = StatisticalMath.pValue(r: r, n: n)
                    let effect = StatisticalMath.effectSize(a: aValues, b: bValues)
                    let confidence = StatisticalMath.classifyConfidence(r: r, p: p, n: n)

                    computed.append(CorrelationResult(
                        pairId: pairId,
                        lagHours: lag,
                        r: r,
                        pValue: p,
                        n: n,
                        effectSize: effect,
                        confidence: confidence,
                        computedAt: Date()
                    ))
                }
                return computed
            }.value

            guard !Task.isCancelled else { return }
            await cache.save(results: results, pairId: pair.id)
        }
    }

}
