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
    private let cache: CacheActor?

    init(
        healthKit: any HealthKitProviding,
        engine: any CorrelationProviding,
        narrator: any NarrationProviding,
        cache: CacheActor? = nil
    ) {
        self.healthKit = healthKit
        self.engine = engine
        self.narrator = narrator
        self.cache = cache
    }

    convenience init() {
        let cache = CacheActor()
        self.init(
            healthKit: HealthKitManager(),
            engine: CorrelationEngine(cache: cache),
            narrator: PatternNarrator(cache: cache),
            cache: cache
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
        await cache?.clearNarrationCache()
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
        let spo2 = await spo2Data
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
            body: narration?.body ?? "Pattern detected with r=\(String(format: "%.2f", best.r)), based on \(best.n) days of data.",
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
        case "sleep": return "Sleep (hrs)"
        case "hrv": return "HRV (ms)"
        case "steps": return "Steps"
        case "rhr": return "Resting HR (bpm)"
        case "activeEnergy": return "Active Energy (kcal)"
        case "exerciseTime": return "Exercise (min)"
        case "distance": return "Distance (km)"
        case "vo2Max": return "VO2 Max (mL/kg/min)"
        case "walkingHR": return "Walking HR (bpm)"
        case "spo2": return "SpO2 (%)"
        case "respiratoryRate": return "Resp. Rate (br/min)"
        case "bodyMass": return "Body Mass (kg)"
        default: return key
        }
    }

}
