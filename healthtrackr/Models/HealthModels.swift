import Foundation

struct MetricSample: Codable {
    let date: Date
    let value: Double
}

struct CorrelationResult: Codable {
    let pairId: String
    let lagHours: Int
    let r: Double
    let pValue: Double
    let n: Int
    let effectSize: Double?
    let confidence: Confidence
    let computedAt: Date

    enum Confidence: String, Codable {
        case high, medium, emerging, hidden
    }
}

struct MetricPair {
    let id: String
    let metricA: [MetricSample]
    let metricB: [MetricSample]
}

struct PatternNarration: Codable {
    let pairId: String
    let headline: String
    let body: String
    let cachedAt: Date
}
