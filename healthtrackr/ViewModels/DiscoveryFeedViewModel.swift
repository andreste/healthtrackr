import SwiftUI

// MARK: - Dependency Protocols

@MainActor
protocol HealthKitProviding {
    var needsAuthorization: Bool { get }
    func requestAuthorization() async throws
    func fetchSleep(days: Int) async -> [MetricSample]
    func fetchHRV(days: Int) async -> [MetricSample]
    func fetchSteps(days: Int) async -> [MetricSample]
    func fetchRestingHR(days: Int) async -> [MetricSample]
}

extension HealthKitManager: HealthKitProviding {}

@MainActor
protocol CorrelationProviding {
    func cachedResults(for pairId: String) async -> [CorrelationResult]
    func run(pairs: [MetricPair])
}

extension CorrelationEngine: CorrelationProviding {}

protocol NarrationProviding: Sendable {
    func narrate(results: [CorrelationResult]) async -> [PatternNarration]
}

extension PatternNarrator: NarrationProviding {}

// MARK: - ViewModel

@MainActor @Observable
final class DiscoveryFeedViewModel {
    // MARK: - Filter

    enum Filter: String, CaseIterable {
        case all = "All"
        case sleepHRV = "Sleep + HRV"
        case stepsHR = "Steps + HR"

        var pairIds: [String]? {
            switch self {
            case .all: return nil
            case .sleepHRV: return ["sleep_hrv"]
            case .stepsHR: return ["steps_rhr"]
            }
        }
    }

    // MARK: - Feed Item

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
    }

    // MARK: - State

    enum FeedState: Equatable {
        case loading
        case loaded
        case empty
        case healthKitDenied
    }

    var feedState: FeedState = .loading
    var selectedFilter: Filter = .all
    var items: [PatternItem] = []
    var loadingPairIds: Set<String> = []
    var lastUpdated: Date?
    var showSettings = false

    var filteredItems: [PatternItem] {
        guard let allowedPairs = selectedFilter.pairIds else { return items }
        return items.filter { allowedPairs.contains($0.pairId) }
    }

    var lastUpdatedText: String? {
        guard let date = lastUpdated else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Dependencies

    private let healthKit: any HealthKitProviding
    private let engine: any CorrelationProviding
    private let narrator: any NarrationProviding

    init(
        healthKit: any HealthKitProviding,
        engine: any CorrelationProviding,
        narrator: any NarrationProviding
    ) {
        self.healthKit = healthKit
        self.engine = engine
        self.narrator = narrator
    }

    convenience init() {
        self.init(
            healthKit: HealthKitManager(),
            engine: CorrelationEngine(),
            narrator: PatternNarrator()
        )
    }

    // MARK: - Load

    func load() async {
        feedState = .loading
        loadingPairIds = Set(CorrelationEngine.v1Pairs.map(\.id))

        // Request HealthKit authorization
        do {
            try await healthKit.requestAuthorization()
        } catch {
            feedState = .healthKitDenied
            loadingPairIds = []
            return
        }

        if healthKit.needsAuthorization {
            feedState = .healthKitDenied
            loadingPairIds = []
            return
        }

        // Load cached results first for instant display
        await loadCachedResults()

        // Fetch fresh data in background
        await fetchAndCorrelate()
    }

    private func loadCachedResults() async {
        var cachedItems: [PatternItem] = []

        for pair in CorrelationEngine.v1Pairs {
            let results = await engine.cachedResults(for: pair.id)
            let narrations = await narrateResults(results)
            cachedItems.append(contentsOf: buildItems(from: results, narrations: narrations))
        }

        if !cachedItems.isEmpty {
            items = cachedItems
            feedState = .loaded
            lastUpdated = Date()
        }
    }

    private func fetchAndCorrelate() async {
        // Fetch all metrics in parallel
        async let sleepData = healthKit.fetchSleep(days: 90)
        async let hrvData = healthKit.fetchHRV(days: 90)
        async let stepsData = healthKit.fetchSteps(days: 90)
        async let rhrData = healthKit.fetchRestingHR(days: 90)

        let sleep = await sleepData
        let hrv = await hrvData
        let steps = await stepsData
        let rhr = await rhrData

        let pairs = [
            MetricPair(id: "sleep_hrv", metricA: sleep, metricB: hrv),
            MetricPair(id: "steps_rhr", metricA: steps, metricB: rhr),
        ]

        // Run correlation
        engine.run(pairs: pairs)

        // Wait briefly for engine to finish, then collect results
        try? await Task.sleep(for: .milliseconds(500))

        var allItems: [PatternItem] = []

        for pair in CorrelationEngine.v1Pairs {
            let results = await engine.cachedResults(for: pair.id)
            loadingPairIds.remove(pair.id)

            let narrations = await narrateResults(results)
            allItems.append(contentsOf: buildItems(from: results, narrations: narrations))
        }

        items = allItems
        lastUpdated = Date()
        loadingPairIds = []
        feedState = allItems.isEmpty ? .empty : .loaded
    }

    private func narrateResults(_ results: [CorrelationResult]) async -> [PatternNarration] {
        let confirmed = results.filter { $0.confidence == .high || $0.confidence == .medium }
        guard !confirmed.isEmpty else { return [] }
        return await narrator.narrate(results: confirmed)
    }

    func buildItems(from results: [CorrelationResult], narrations: [PatternNarration]) -> [PatternItem] {
        let confirmed = results.filter { $0.confidence == .high || $0.confidence == .medium }
        guard !confirmed.isEmpty else { return [] }

        // Pick the best result per pair (highest |r|)
        let best = confirmed.max(by: { abs($0.r) < abs($1.r) })!
        let narration = narrations.first { $0.pairId == best.pairId }

        return [PatternItem(
            id: "\(best.pairId)_\(best.lagHours)",
            pairId: best.pairId,
            pairLabel: humanReadablePair(best.pairId),
            headline: narration?.headline ?? humanReadablePair(best.pairId),
            body: narration?.body ?? "Pattern detected with r=\(String(format: "%.2f", best.r)), based on \(best.n) days of data.",
            confidence: best.confidence,
            r: best.r,
            n: best.n,
            lagHours: best.lagHours
        )]
    }

    func humanReadablePair(_ pairId: String) -> String {
        switch pairId {
        case "sleep_hrv": return "SLEEP + HRV"
        case "steps_rhr": return "STEPS + HR"
        default: return pairId.uppercased()
        }
    }
}
