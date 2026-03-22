import Foundation

struct MetricSample: Codable {
    let date: Date
    let value: Double
}

struct DayBucket: Codable {
    let date: Date
    var sleepHours: Double?
    var hrvMs: Double?
    var steps: Double?
    var restingHR: Double?
}

struct CorrelationResult: Codable {
    let pairId: String
    let lagHours: Int
    let r: Double
    let pValue: Double
    let n: Int
    let effectSize: Double
    let confidence: Confidence
    let computedAt: Date

    enum Confidence: String, Codable {
        case high, medium, emerging, hidden
    }
}

struct PatternNarration: Codable {
    let pairId: String
    let headline: String
    let body: String
    let cachedAt: Date
}
