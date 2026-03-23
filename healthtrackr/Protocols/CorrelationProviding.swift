import Foundation

@MainActor
protocol CorrelationProviding {
    func cachedResults(for pairId: String) async -> [CorrelationResult]
    func run(pairs: [MetricPair]) async
}

extension CorrelationEngine: CorrelationProviding {}
