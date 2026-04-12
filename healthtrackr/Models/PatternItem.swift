import Foundation

struct ScatterPoint: Identifiable {
    let id = UUID()
    let date: Date
    let metricA: Double
    let metricB: Double
}

struct PatternItem: Identifiable {
    let id: String
    let pairId: String
    let pairLabel: String
    let headline: String
    let body: String
    let confidence: CorrelationResult.Confidence
    let r: Double
    let n: Int
    let lagHours: Int
    let effectSize: Double?
    let scatterData: [ScatterPoint]
    let metricALabel: String
    let metricBLabel: String
}
