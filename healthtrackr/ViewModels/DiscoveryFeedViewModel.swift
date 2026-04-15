import SwiftUI

@MainActor @Observable
final class DiscoveryFeedViewModel {
    // MARK: - Filter

    enum Filter: String, CaseIterable {
        case all = "All"
        case sleep = "Sleep"
        case steps = "Steps"
        case energy = "Energy"
        case exercise = "Exercise"
        case vo2Max = "VO2 Max"
        case distance = "Distance"
        case body = "Body"

        var pairIds: [String]? {
            switch self {
            case .all: return nil
            case .sleep: return ["sleep_hrv", "sleep_rhr", "sleep_walkingHR", "sleep_respiratoryRate", "sleep_spo2"]
            case .steps: return ["steps_rhr", "steps_hrv", "steps_walkingHR"]
            case .energy: return ["activeEnergy_hrv", "activeEnergy_rhr"]
            case .exercise: return ["exerciseTime_rhr", "exerciseTime_hrv", "exerciseTime_walkingHR"]
            case .vo2Max: return ["vo2Max_rhr", "vo2Max_hrv", "vo2Max_walkingHR"]
            case .distance: return ["distance_rhr", "distance_hrv"]
            case .body: return ["bodyMass_rhr", "bodyMass_vo2Max"]
            }
        }
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
    var showSettings = false

    private var metricSamples: [String: [MetricSample]] = [:]

    var filteredItems: [PatternItem] {
        guard let allowedPairs = selectedFilter.pairIds else { return items }
        return items.filter { allowedPairs.contains($0.pairId) }
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
        let cache = CacheActor()
        self.init(
            healthKit: HealthKitManager(),
            engine: CorrelationEngine(cache: cache),
            narrator: PatternNarrator(cache: cache)
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

    func renarrate() async {
        await narrator.clearNarrationCache()
        var allItems: [PatternItem] = []
        for pair in CorrelationEngine.v1Pairs {
            let results = await engine.cachedResults(for: pair.id)
            let narrations = await narrateResults(results)
            allItems.append(contentsOf: buildItems(from: results, narrations: narrations))
        }
        if !allItems.isEmpty {
            items = allItems
        }
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
        }
    }

    private func fetchAndCorrelate() async {
        // Fetch all metrics in parallel
        async let sleepData = healthKit.fetchSleep(days: 90)
        async let hrvData = healthKit.fetchHRV(days: 90)
        async let stepsData = healthKit.fetchSteps(days: 90)
        async let rhrData = healthKit.fetchRestingHR(days: 90)
        async let activeEnergyData = healthKit.fetchActiveEnergy(days: 90)
        async let exerciseTimeData = healthKit.fetchExerciseTime(days: 90)
        async let distanceData = healthKit.fetchDistance(days: 90)
        async let vo2MaxData = healthKit.fetchVO2Max(days: 90)
        async let walkingHRData = healthKit.fetchWalkingHR(days: 90)
        async let spo2Data = healthKit.fetchOxygenSaturation(days: 90)
        async let respiratoryRateData = healthKit.fetchRespiratoryRate(days: 90)
        async let bodyMassData = healthKit.fetchBodyMass(days: 90)

        let sleep = await sleepData
        let hrv = await hrvData
        let steps = await stepsData
        let rhr = await rhrData
        let activeEnergy = await activeEnergyData
        let exerciseTime = await exerciseTimeData
        let distance = await distanceData
        let vo2Max = await vo2MaxData
        let walkingHR = await walkingHRData
        // Scale SpO2 from fractional (0.95–0.99) to percentage (95–99) for display and correlation.
        let spo2 = (await spo2Data).map { MetricSample(date: $0.date, value: $0.value * 100) }
        let respiratoryRate = await respiratoryRateData
        let bodyMass = await bodyMassData

        metricSamples = [
            "sleep": sleep, "hrv": hrv,
            "steps": steps, "rhr": rhr,
            "activeEnergy": activeEnergy, "exerciseTime": exerciseTime,
            "distance": distance, "vo2Max": vo2Max,
            "walkingHR": walkingHR, "spo2": spo2,
            "respiratoryRate": respiratoryRate, "bodyMass": bodyMass,
        ]

        let pairs = CorrelationEngine.v1Pairs.map { pairDef in
            MetricPair(
                id: pairDef.id,
                metricA: metricSamples[pairDef.metricAKey] ?? [],
                metricB: metricSamples[pairDef.metricBKey] ?? []
            )
        }

        // Run correlation and await completion
        await engine.run(pairs: pairs)

        var allItems: [PatternItem] = []

        for pair in CorrelationEngine.v1Pairs {
            let results = await engine.cachedResults(for: pair.id)
            loadingPairIds.remove(pair.id)

            let narrations = await narrateResults(results)
            allItems.append(contentsOf: buildItems(from: results, narrations: narrations))
        }

        items = allItems
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
        let (metricAKey, metricBKey) = metricKeys(for: best.pairId)
        let aligned = MetricAlignment.align(
            a: metricSamples[metricAKey] ?? [],
            b: metricSamples[metricBKey] ?? [],
            lagHours: best.lagHours
        )
        let scatter = aligned.map { pair in
            ScatterPoint(date: pair.date, metricA: pair.a, metricB: pair.b)
        }

        return [PatternItem(
            id: "\(best.pairId)_\(best.lagHours)",
            pairId: best.pairId,
            pairLabel: humanReadablePair(best.pairId),
            headline: narration?.headline ?? humanReadablePair(best.pairId),
            body: narration?.body ?? String(
                format: String(localized: "Pattern detected with r=%@, based on %lld days of data.", bundle: Bundle.localization),
                String(format: "%.2f", best.r),
                Int64(best.n)
            ),
            confidence: best.confidence,
            r: best.r,
            n: best.n,
            lagHours: best.lagHours,
            effectSize: best.effectSize,
            scatterData: scatter,
            metricALabel: metricLabel(metricAKey),
            metricBLabel: metricLabel(metricBKey)
        )]
    }

    func humanReadablePair(_ pairId: String) -> String {
        CorrelationEngine.v1Pairs.first(where: { $0.id == pairId })?.shortLabel ?? pairId.uppercased()
    }

    func metricKeys(for pairId: String) -> (String, String) {
        guard let pair = CorrelationEngine.v1Pairs.first(where: { $0.id == pairId }) else {
            return ("", "")
        }
        return (pair.metricAKey, pair.metricBKey)
    }

    func metricLabel(_ key: String) -> String {
        switch key {
        case "sleep": return String(localized: "metric.label.sleep", bundle: Bundle.localization)
        case "hrv": return String(localized: "metric.label.hrv", bundle: Bundle.localization)
        case "steps": return String(localized: "metric.label.steps", bundle: Bundle.localization)
        case "rhr": return String(localized: "metric.label.rhr", bundle: Bundle.localization)
        case "activeEnergy": return String(localized: "metric.label.activeEnergy", bundle: Bundle.localization)
        case "exerciseTime": return String(localized: "metric.label.exerciseTime", bundle: Bundle.localization)
        case "distance": return String(localized: "metric.label.distance", bundle: Bundle.localization)
        case "vo2Max": return String(localized: "metric.label.vo2Max", bundle: Bundle.localization)
        case "walkingHR": return String(localized: "metric.label.walkingHR", bundle: Bundle.localization)
        case "spo2": return String(localized: "metric.label.spo2", bundle: Bundle.localization)
        case "respiratoryRate": return String(localized: "metric.label.respiratoryRate", bundle: Bundle.localization)
        case "bodyMass": return String(localized: "metric.label.bodyMass", bundle: Bundle.localization)
        default: return key
        }
    }

}
