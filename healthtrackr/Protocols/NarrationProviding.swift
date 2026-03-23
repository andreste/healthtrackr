import Foundation

protocol NarrationProviding: Sendable {
    func narrate(results: [CorrelationResult]) async -> [PatternNarration]
}

extension PatternNarrator: NarrationProviding {}
