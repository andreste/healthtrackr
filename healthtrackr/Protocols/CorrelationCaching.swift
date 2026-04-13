import Foundation

protocol CorrelationCaching: Sendable {
    func loadAll(pairId: String) async -> [CorrelationResult]
    func save(results: [CorrelationResult], pairId: String) async
    func isStale(pairId: String, maxAge: TimeInterval) async -> Bool
}

extension CacheActor: CorrelationCaching {}
