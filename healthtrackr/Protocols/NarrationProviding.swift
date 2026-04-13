import Foundation

protocol NarrationProviding: Sendable {
    func narrate(results: [CorrelationResult]) async -> [PatternNarration]
    func clearNarrationCache() async
}

extension PatternNarrator: NarrationProviding {}
