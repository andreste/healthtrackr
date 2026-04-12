import Foundation
import Testing
@testable import healthtrackr

// MARK: - Spearman Tests

@Suite("Spearman Correlation")
struct SpearmanTests {
    @Test("perfect positive correlation returns ~1.0")
    func perfectPositive() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [10.0, 20.0, 30.0, 40.0, 50.0]
        let r = StatisticalMath.spearmanR(x: x, y: y)
        #expect(abs(r - 1.0) < 0.001)
    }

    @Test("perfect negative correlation returns ~-1.0")
    func perfectNegative() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [50.0, 40.0, 30.0, 20.0, 10.0]
        let r = StatisticalMath.spearmanR(x: x, y: y)
        #expect(abs(r - (-1.0)) < 0.001)
    }

    @Test("no correlation returns ~0")
    func noCorrelation() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [3.0, 1.0, 5.0, 2.0, 4.0]
        let r = StatisticalMath.spearmanR(x: x, y: y)
        #expect(abs(r) < 0.5)
    }

    @Test("fewer than 3 values returns 0")
    func tooFewValues() {
        let r = StatisticalMath.spearmanR(x: [1.0, 2.0], y: [3.0, 4.0])
        #expect(r == 0)
    }
}

// MARK: - Rank Tests

@Suite("Rank Computation")
struct RankTests {
    @Test("distinct values get sequential ranks")
    func distinctValues() {
        let ranks = StatisticalMath.computeRanks([30.0, 10.0, 20.0])
        #expect(ranks == [3.0, 1.0, 2.0])
    }

    @Test("tied values get averaged ranks")
    func tiedValues() {
        let ranks = StatisticalMath.computeRanks([10.0, 20.0, 20.0, 30.0])
        // 20.0 appears at positions 2 and 3 → avg rank = 2.5
        #expect(ranks == [1.0, 2.5, 2.5, 4.0])
    }

    @Test("all same values get same rank")
    func allSame() {
        let ranks = StatisticalMath.computeRanks([5.0, 5.0, 5.0])
        #expect(ranks == [2.0, 2.0, 2.0])
    }
}

// MARK: - Pearson Tests

@Suite("Pearson Correlation")
struct PearsonTests {
    @Test("perfect linear correlation returns 1.0")
    func perfectLinear() {
        let x = [1.0, 2.0, 3.0, 4.0, 5.0]
        let y = [2.0, 4.0, 6.0, 8.0, 10.0]
        let r = StatisticalMath.pearsonR(x: x, y: y)
        #expect(abs(r - 1.0) < 0.0001)
    }

    @Test("constant values return 0")
    func constantValues() {
        let x = [1.0, 2.0, 3.0]
        let y = [5.0, 5.0, 5.0]
        let r = StatisticalMath.pearsonR(x: x, y: y)
        #expect(r == 0)
    }
}

// MARK: - P-Value Tests

@Suite("P-Value")
struct PValueTests {
    @Test("strong correlation with many points has low p-value")
    func strongCorrelation() {
        let p = StatisticalMath.pValue(r: 0.9, n: 50)
        #expect(p < 0.01)
    }

    @Test("weak correlation has high p-value")
    func weakCorrelation() {
        let p = StatisticalMath.pValue(r: 0.1, n: 10)
        #expect(p > 0.5)
    }

    @Test("n <= 2 returns 1.0")
    func tooFewSamples() {
        #expect(StatisticalMath.pValue(r: 0.9, n: 2) == 1.0)
    }

    @Test("perfect correlation returns 0.0")
    func perfectCorrelation() {
        #expect(StatisticalMath.pValue(r: 1.0, n: 50) == 0.0)
    }
}

// MARK: - Effect Size Tests

@Suite("Effect Size")
struct EffectSizeTests {
    @Test("identical distributions return nil (zero pooled std dev)")
    func identicalDistributions() {
        let result = StatisticalMath.effectSize(a: [5.0, 5.0, 5.0], b: [5.0, 5.0, 5.0])
        #expect(result == nil)
    }

    @Test("clearly separated distributions return large Cohen's d")
    func separatedDistributions() {
        // group A: mean≈10, group B: mean≈0, std dev≈1
        let a = [9.0, 10.0, 11.0, 10.0, 10.0]
        let b = [0.0, 1.0, -1.0, 0.5, -0.5]
        let d = StatisticalMath.effectSize(a: a, b: b)
        #expect(d != nil)
        #expect(d! > 5.0)
    }

    @Test("d≈0 when means are equal")
    func equalMeans() {
        let a = [1.0, 2.0, 3.0, 4.0, 5.0] // mean=3
        let b = [2.0, 3.0, 4.0, 5.0, 1.0] // mean=3
        let d = StatisticalMath.effectSize(a: a, b: b)
        #expect(d != nil)
        #expect(abs(d!) < 0.001)
    }

    @Test("empty arrays return nil")
    func emptyArrays() {
        #expect(StatisticalMath.effectSize(a: [], b: []) == nil)
    }

    @Test("single-element arrays return nil")
    func singleElementArrays() {
        #expect(StatisticalMath.effectSize(a: [5.0], b: [10.0]) == nil)
    }

    @Test("one array too small returns nil")
    func oneArrayTooSmall() {
        #expect(StatisticalMath.effectSize(a: [1.0, 2.0, 3.0], b: [5.0]) == nil)
    }

    @Test("negative d when mean of a is less than mean of b")
    func negativeCohensD() {
        let a = [1.0, 2.0, 1.0, 2.0]  // mean=1.5
        let b = [9.0, 10.0, 9.0, 10.0] // mean=9.5
        let d = StatisticalMath.effectSize(a: a, b: b)
        #expect(d != nil)
        #expect(d! < -5.0)
    }
}

// MARK: - Confidence Classification Tests

@Suite("Confidence Classification")
struct ConfidenceClassificationTests {
    @Test("n < 20 returns hidden")
    func hiddenWhenTooFew() {
        #expect(StatisticalMath.classifyConfidence(r: 0.9, p: 0.001, n: 15) == .hidden)
    }

    @Test("n between 20 and 29 returns emerging regardless of p")
    func emergingWhenModerate() {
        #expect(StatisticalMath.classifyConfidence(r: 0.9, p: 0.001, n: 25) == .emerging)
    }

    @Test("n >= 30 and p < 0.01 returns high")
    func highConfidence() {
        #expect(StatisticalMath.classifyConfidence(r: 0.8, p: 0.005, n: 50) == .high)
    }

    @Test("n >= 30 and p < 0.05 returns medium")
    func mediumConfidence() {
        #expect(StatisticalMath.classifyConfidence(r: 0.4, p: 0.03, n: 40) == .medium)
    }

    @Test("n >= 30 and p >= 0.05 returns emerging")
    func emergingHighP() {
        #expect(StatisticalMath.classifyConfidence(r: 0.2, p: 0.1, n: 35) == .emerging)
    }
}
