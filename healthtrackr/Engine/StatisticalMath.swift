import Accelerate
import Foundation

enum StatisticalMath {
    // MARK: - Spearman Rank Correlation

    static func spearmanR(x: [Double], y: [Double]) -> Double {
        let n = x.count
        guard n >= 3 else { return 0 }

        let ranksX = computeRanks(x)
        let ranksY = computeRanks(y)

        return pearsonR(x: ranksX, y: ranksY)
    }

    static func computeRanks(_ values: [Double]) -> [Double] {
        let n = values.count
        let indexed = values.enumerated().sorted { $0.element < $1.element }
        var ranks = [Double](repeating: 0, count: n)

        var i = 0
        while i < n {
            var j = i
            while j < n - 1 && indexed[j + 1].element == indexed[j].element {
                j += 1
            }
            let avgRank = Double(i + j) / 2.0 + 1.0
            for k in i...j {
                ranks[indexed[k].offset] = avgRank
            }
            i = j + 1
        }
        return ranks
    }

    static func pearsonR(x: [Double], y: [Double]) -> Double {
        let n = vDSP_Length(x.count)
        guard n >= 3 else { return 0 }

        var meanX = 0.0, meanY = 0.0
        vDSP_meanvD(x, 1, &meanX, n)
        vDSP_meanvD(y, 1, &meanY, n)

        var negMeanX = -meanX, negMeanY = -meanY
        var dx = [Double](repeating: 0, count: Int(n))
        var dy = [Double](repeating: 0, count: Int(n))
        vDSP_vsaddD(x, 1, &negMeanX, &dx, 1, n)
        vDSP_vsaddD(y, 1, &negMeanY, &dy, 1, n)

        var dotXY = 0.0, dotXX = 0.0, dotYY = 0.0
        vDSP_dotprD(dx, 1, dy, 1, &dotXY, n)
        vDSP_dotprD(dx, 1, dx, 1, &dotXX, n)
        vDSP_dotprD(dy, 1, dy, 1, &dotYY, n)

        let denom = sqrt(dotXX * dotYY)
        guard denom > 0 else { return 0 }
        return dotXY / denom
    }

    // MARK: - P-Value

    static func pValue(r: Double, n: Int) -> Double {
        guard n > 2 else { return 1.0 }
        let r2 = r * r
        guard r2 < 1.0 else { return 0.0 }

        let t = abs(r) * sqrt(Double(n - 2)) / sqrt(1.0 - r2)
        let df = Double(n - 2)

        let x = df / (df + t * t)
        let p = regularizedIncompleteBeta(a: df / 2.0, b: 0.5, x: x)
        return min(p, 1.0)
    }

    static func regularizedIncompleteBeta(a: Double, b: Double, x: Double) -> Double {
        guard x > 0 else { return 0.0 }
        guard x < 1 else { return 1.0 }

        let lnBeta = lgamma(a) + lgamma(b) - lgamma(a + b)
        let front = exp(a * log(x) + b * log(1.0 - x) - lnBeta)

        if x < (a + 1.0) / (a + b + 2.0) {
            return front * betaCF(a: a, b: b, x: x) / a
        } else {
            return 1.0 - front * betaCF(a: b, b: a, x: 1.0 - x) / b
        }
    }

    static func betaCF(a: Double, b: Double, x: Double) -> Double {
        let maxIterations = 200
        let epsilon = 1e-10
        let tiny = 1e-30

        var c = 1.0
        var d = 1.0 / max(1.0 - (a + b) * x / (a + 1.0), tiny)
        var h = d

        for m in 1...maxIterations {
            let dm = Double(m)

            var num = dm * (b - dm) * x / ((a + 2.0 * dm - 1.0) * (a + 2.0 * dm))
            d = 1.0 / max(1.0 + num * d, tiny)
            c = max(1.0 + num / c, tiny)
            h *= d * c

            num = -(a + dm) * (a + b + dm) * x / ((a + 2.0 * dm) * (a + 2.0 * dm + 1.0))
            d = 1.0 / max(1.0 + num * d, tiny)
            c = max(1.0 + num / c, tiny)
            h *= d * c

            if abs(d * c - 1.0) < epsilon { break }
        }
        return h
    }

    // MARK: - Effect Size

    /// Cohen's d: standardized mean difference between two samples.
    /// Returns nil when either array has fewer than 2 elements or the pooled
    /// standard deviation is zero (e.g. both distributions are constant).
    static func effectSize(a: [Double], b: [Double]) -> Double? {
        let nA = a.count
        let nB = b.count
        guard nA >= 2, nB >= 2 else { return nil }

        let meanA = a.reduce(0, +) / Double(nA)
        let meanB = b.reduce(0, +) / Double(nB)

        let varA = a.reduce(0) { $0 + ($1 - meanA) * ($1 - meanA) } / Double(nA - 1)
        let varB = b.reduce(0) { $0 + ($1 - meanB) * ($1 - meanB) } / Double(nB - 1)

        let pooledVariance = (Double(nA - 1) * varA + Double(nB - 1) * varB) / Double(nA + nB - 2)
        let pooledStdDev = sqrt(pooledVariance)

        guard pooledStdDev > 0 else { return nil }

        return (meanA - meanB) / pooledStdDev
    }

    // MARK: - Confidence Classification

    static func classifyConfidence(r: Double, p: Double, n: Int) -> CorrelationResult.Confidence {
        guard n >= 20 else { return .hidden }
        guard n >= 30 else { return .emerging }
        if p < 0.01 { return .high }
        if p < 0.05 { return .medium }
        return .emerging
    }
}
