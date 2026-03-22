import Accelerate
import Foundation

struct MetricPair {
    let id: String
    let metricA: [MetricSample]
    let metricB: [MetricSample]
}

@MainActor
final class CorrelationEngine {
    private let cache = CacheActor()
    private var currentTask: Task<Void, Never>?

    static let lagOffsets = [0, 12, 24, 36, 48]

    static let v1Pairs: [(id: String, metricAKey: String, metricBKey: String)] = [
        ("sleep_hrv", "sleep", "hrv"),
        ("steps_rhr", "steps", "rhr"),
    ]

    // MARK: - Public

    func cachedResults(for pairId: String) async -> [CorrelationResult] {
        await cache.loadAll(pairId: pairId)
    }

    func run(pairs: [MetricPair]) {
        currentTask?.cancel()
        currentTask = Task {
            for pair in pairs {
                let isStale = await cache.isStale(pairId: pair.id)
                guard isStale else { continue }

                var results: [CorrelationResult] = []
                for lag in Self.lagOffsets {
                    guard !Task.isCancelled else { return }

                    let aligned = alignSamples(a: pair.metricA, b: pair.metricB, lagHours: lag)
                    guard aligned.count >= 20 else {
                        results.append(CorrelationResult(
                            pairId: pair.id,
                            lagHours: lag,
                            r: 0,
                            pValue: 1,
                            n: aligned.count,
                            effectSize: 0,
                            confidence: .hidden,
                            computedAt: Date()
                        ))
                        continue
                    }

                    let aValues = aligned.map(\.a)
                    let bValues = aligned.map(\.b)

                    let r = spearmanR(x: aValues, y: bValues)
                    let n = aligned.count
                    let p = pValue(r: r, n: n)
                    let effect = effectSize(a: aValues, b: bValues)
                    let confidence = classifyConfidence(r: r, p: p, n: n)

                    results.append(CorrelationResult(
                        pairId: pair.id,
                        lagHours: lag,
                        r: r,
                        pValue: p,
                        n: n,
                        effectSize: effect,
                        confidence: confidence,
                        computedAt: Date()
                    ))
                }

                guard !Task.isCancelled else { return }
                await cache.save(results: results, pairId: pair.id)
            }
        }
    }

    // MARK: - Alignment

    private struct AlignedPair {
        let a: Double
        let b: Double
    }

    private func alignSamples(
        a: [MetricSample],
        b: [MetricSample],
        lagHours: Int
    ) -> [AlignedPair] {
        let calendar = Calendar.current
        let lagDays = lagHours / 24
        let hasHalfDayOffset = (lagHours % 24) == 12

        // Build lookup for metric B by day
        var bByDay: [Date: Double] = [:]
        for sample in b {
            let day = calendar.startOfDay(for: sample.date)
            bByDay[day] = sample.value
        }

        var pairs: [AlignedPair] = []
        for sample in a {
            let dayA = calendar.startOfDay(for: sample.date)

            if hasHalfDayOffset {
                // For 12h/36h lags, average the current and next day of metric B
                guard let dayB1 = calendar.date(byAdding: .day, value: lagDays, to: dayA),
                      let dayB2 = calendar.date(byAdding: .day, value: lagDays + 1, to: dayA),
                      let val1 = bByDay[dayB1],
                      let val2 = bByDay[dayB2] else { continue }
                pairs.append(AlignedPair(a: sample.value, b: (val1 + val2) / 2.0))
            } else {
                guard let dayB = calendar.date(byAdding: .day, value: lagDays, to: dayA),
                      let valB = bByDay[dayB] else { continue }
                pairs.append(AlignedPair(a: sample.value, b: valB))
            }
        }
        return pairs
    }

    // MARK: - Spearman Rank Correlation (Accelerate)

    private func spearmanR(x: [Double], y: [Double]) -> Double {
        let n = x.count
        guard n >= 3 else { return 0 }

        let ranksX = computeRanks(x)
        let ranksY = computeRanks(y)

        // Spearman r = Pearson r of ranks
        return pearsonR(x: ranksX, y: ranksY)
    }

    private func computeRanks(_ values: [Double]) -> [Double] {
        let n = values.count
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var ranks = [Double](repeating: 0, count: n)

        var i = 0
        while i < n {
            var j = i
            while j < n - 1 && indexed[j + 1].element == indexed[j].element {
                j += 1
            }
            // Average rank for ties
            let avgRank = Double(i + j) / 2.0 + 1.0
            for k in i...j {
                ranks[indexed[k].offset] = avgRank
            }
            i = j + 1
        }
        return ranks
    }

    private func pearsonR(x: [Double], y: [Double]) -> Double {
        let n = vDSP_Length(x.count)
        guard n >= 3 else { return 0 }

        var meanX = 0.0, meanY = 0.0
        vDSP_meanvD(x, 1, &meanX, n)
        vDSP_meanvD(y, 1, &meanY, n)

        // Center the data
        var negMeanX = -meanX, negMeanY = -meanY
        var dx = [Double](repeating: 0, count: Int(n))
        var dy = [Double](repeating: 0, count: Int(n))
        vDSP_vsaddD(x, 1, &negMeanX, &dx, 1, n)
        vDSP_vsaddD(y, 1, &negMeanY, &dy, 1, n)

        // dot(dx, dy), dot(dx, dx), dot(dy, dy)
        var dotXY = 0.0, dotXX = 0.0, dotYY = 0.0
        vDSP_dotprD(dx, 1, dy, 1, &dotXY, n)
        vDSP_dotprD(dx, 1, dx, 1, &dotXX, n)
        vDSP_dotprD(dy, 1, dy, 1, &dotYY, n)

        let denom = sqrt(dotXX * dotYY)
        guard denom > 0 else { return 0 }
        return dotXY / denom
    }

    // MARK: - P-Value (t-distribution approximation)

    private func pValue(r: Double, n: Int) -> Double {
        guard n > 2 else { return 1.0 }
        let r2 = r * r
        guard r2 < 1.0 else { return 0.0 }

        let t = abs(r) * sqrt(Double(n - 2)) / sqrt(1.0 - r2)
        let df = Double(n - 2)

        // Two-tailed p-value using regularized incomplete beta function
        let x = df / (df + t * t)
        let p = regularizedIncompleteBeta(a: df / 2.0, b: 0.5, x: x)
        return min(p, 1.0)
    }

    /// Regularized incomplete beta function via continued fraction (Lentz's method)
    /// Abramowitz & Stegun 26.5.8
    private func regularizedIncompleteBeta(a: Double, b: Double, x: Double) -> Double {
        guard x > 0 else { return 0.0 }
        guard x < 1 else { return 1.0 }

        let lnBeta = lgamma(a) + lgamma(b) - lgamma(a + b)
        let front = exp(a * log(x) + b * log(1.0 - x) - lnBeta)

        // Use continued fraction when x < (a+1)/(a+b+2), otherwise use symmetry
        if x < (a + 1.0) / (a + b + 2.0) {
            return front * betaCF(a: a, b: b, x: x) / a
        } else {
            return 1.0 - front * betaCF(a: b, b: a, x: 1.0 - x) / b
        }
    }

    /// Continued fraction for incomplete beta (Lentz's method)
    private func betaCF(a: Double, b: Double, x: Double) -> Double {
        let maxIterations = 200
        let epsilon = 1e-10
        let tiny = 1e-30

        var c = 1.0
        var d = 1.0 / max(1.0 - (a + b) * x / (a + 1.0), tiny)
        var h = d

        for m in 1...maxIterations {
            let dm = Double(m)

            // Even step
            var num = dm * (b - dm) * x / ((a + 2.0 * dm - 1.0) * (a + 2.0 * dm))
            d = 1.0 / max(1.0 + num * d, tiny)
            c = max(1.0 + num / c, tiny)
            h *= d * c

            // Odd step
            num = -(a + dm) * (a + b + dm) * x / ((a + 2.0 * dm) * (a + 2.0 * dm + 1.0))
            d = 1.0 / max(1.0 + num * d, tiny)
            c = max(1.0 + num / c, tiny)
            h *= d * c

            if abs(d * c - 1.0) < epsilon { break }
        }
        return h
    }

    // MARK: - Effect Size

    private func effectSize(a: [Double], b: [Double]) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let meanA = a.reduce(0, +) / Double(a.count)
        let meanB = b.reduce(0, +) / Double(b.count)
        guard meanB != 0 else { return 0 }
        return abs(meanA - meanB) / abs(meanB)
    }

    // MARK: - Confidence Classification

    private func classifyConfidence(r: Double, p: Double, n: Int) -> CorrelationResult.Confidence {
        guard n >= 20 else { return .hidden }
        guard n >= 30 else { return .emerging }
        if p < 0.01 { return .high }
        if p < 0.05 { return .medium }
        return .emerging
    }
}
