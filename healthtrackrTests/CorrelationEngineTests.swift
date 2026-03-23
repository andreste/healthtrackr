import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeSamples(count: Int, startingDaysAgo: Int = 90) -> [MetricSample] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<count).compactMap { i in
        guard let date = calendar.date(byAdding: .day, value: -(startingDaysAgo - i), to: today) else {
            return nil
        }
        return MetricSample(date: date, value: Double.random(in: 1...100))
    }
}

private func makeCorrelatedSamples(count: Int) -> (a: [MetricSample], b: [MetricSample]) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    var a: [MetricSample] = []
    var b: [MetricSample] = []
    for i in 0..<count {
        guard let date = calendar.date(byAdding: .day, value: -(count - i), to: today) else { continue }
        let val = Double(i)
        a.append(MetricSample(date: date, value: val))
        b.append(MetricSample(date: date, value: val * 2))
    }
    return (a, b)
}

// MARK: - CorrelationEngine Tests

@Suite("CorrelationEngine")
struct CorrelationEngineTests {
    @Test("run produces cached results for pairs with sufficient data")
    @MainActor func runProducesCachedResults() async {
        let engine = CorrelationEngine()
        let samples = makeCorrelatedSamples(count: 30)
        let pair = MetricPair(id: "test_pair_sufficient", metricA: samples.a, metricB: samples.b)

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_sufficient")
        #expect(!results.isEmpty)
        #expect(results.count == CorrelationEngine.lagOffsets.count)
    }

    @Test("run produces hidden results when fewer than 20 aligned points")
    @MainActor func insufficientDataProducesHidden() async {
        let engine = CorrelationEngine()
        let samples = makeCorrelatedSamples(count: 10)
        let pair = MetricPair(id: "test_pair_small", metricA: samples.a, metricB: samples.b)

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_small")
        let zeroLagResult = results.first { $0.lagHours == 0 }
        // 10 points < 20 threshold → hidden
        #expect(zeroLagResult?.confidence == .hidden)
        #expect(zeroLagResult?.r == 0)
        #expect(zeroLagResult?.pValue == 1)
    }

    @Test("run sets correct pairId on all results")
    @MainActor func resultsHaveCorrectPairId() async {
        let engine = CorrelationEngine()
        let samples = makeCorrelatedSamples(count: 30)
        let pair = MetricPair(id: "test_pair_id", metricA: samples.a, metricB: samples.b)

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_id")
        for result in results {
            #expect(result.pairId == "test_pair_id")
        }
    }

    @Test("run produces results for all lag offsets")
    @MainActor func resultsForAllLagOffsets() async {
        let engine = CorrelationEngine()
        let samples = makeCorrelatedSamples(count: 60)
        let pair = MetricPair(id: "test_pair_lags", metricA: samples.a, metricB: samples.b)

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_lags")
        let lagHours = Set(results.map(\.lagHours))
        #expect(lagHours == Set(CorrelationEngine.lagOffsets))
    }

    @Test("run with perfectly correlated data produces high r at lag 0")
    @MainActor func perfectCorrelationHighR() async {
        let engine = CorrelationEngine()
        let samples = makeCorrelatedSamples(count: 30)
        let pair = MetricPair(id: "test_pair_perfect", metricA: samples.a, metricB: samples.b)

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_perfect")
        let zeroLag = results.first { $0.lagHours == 0 }
        #expect(zeroLag != nil)
        #expect(zeroLag!.r > 0.9)
        #expect(zeroLag!.pValue < 0.05)
    }

    @Test("run processes multiple pairs")
    @MainActor func processesMultiplePairs() async {
        let engine = CorrelationEngine()
        let samples1 = makeCorrelatedSamples(count: 25)
        let samples2 = makeCorrelatedSamples(count: 25)
        let pairs = [
            MetricPair(id: "test_multi_a", metricA: samples1.a, metricB: samples1.b),
            MetricPair(id: "test_multi_b", metricA: samples2.a, metricB: samples2.b),
        ]

        await engine.run(pairs: pairs)

        let resultsA = await engine.cachedResults(for: "test_multi_a")
        let resultsB = await engine.cachedResults(for: "test_multi_b")
        #expect(!resultsA.isEmpty)
        #expect(!resultsB.isEmpty)
    }

    @Test("cachedResults returns empty for unknown pairId")
    @MainActor func cachedResultsEmptyForUnknown() async {
        let engine = CorrelationEngine()
        let results = await engine.cachedResults(for: "nonexistent_pair_\(UUID().uuidString)")
        #expect(results.isEmpty)
    }

    @Test("v1Pairs has expected configuration")
    func v1PairsConfiguration() {
        #expect(CorrelationEngine.v1Pairs.count == 2)
        #expect(CorrelationEngine.v1Pairs[0].id == "sleep_hrv")
        #expect(CorrelationEngine.v1Pairs[0].metricAKey == "sleep")
        #expect(CorrelationEngine.v1Pairs[0].metricBKey == "hrv")
        #expect(CorrelationEngine.v1Pairs[1].id == "steps_rhr")
        #expect(CorrelationEngine.v1Pairs[1].metricAKey == "steps")
        #expect(CorrelationEngine.v1Pairs[1].metricBKey == "rhr")
    }

    @Test("lagOffsets includes expected values")
    func lagOffsetsValues() {
        #expect(CorrelationEngine.lagOffsets == [0, 12, 24, 36, 48])
    }

    @Test("run with empty metrics produces results with zero r")
    @MainActor func emptyMetricsProduceZeroR() async {
        let engine = CorrelationEngine()
        let pair = MetricPair(id: "test_pair_empty", metricA: [], metricB: [])

        await engine.run(pairs: [pair])

        let results = await engine.cachedResults(for: "test_pair_empty")
        for result in results {
            #expect(result.r == 0)
            #expect(result.pValue == 1)
            #expect(result.confidence == .hidden)
        }
    }
}
