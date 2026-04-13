import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fakes

@MainActor
final class FakeHealthKit: HealthKitProviding {
    var needsAuthorization = false
    var shouldThrowOnAuth = false
    var sleepSamples: [MetricSample] = []
    var hrvSamples: [MetricSample] = []
    var stepsSamples: [MetricSample] = []
    var rhrSamples: [MetricSample] = []
    var activeEnergySamples: [MetricSample] = []
    var exerciseTimeSamples: [MetricSample] = []
    var distanceSamples: [MetricSample] = []
    var vo2MaxSamples: [MetricSample] = []
    var walkingHRSamples: [MetricSample] = []
    var oxygenSaturationSamples: [MetricSample] = []
    var respiratoryRateSamples: [MetricSample] = []
    var bodyMassSamples: [MetricSample] = []

    func requestAuthorization() async throws {
        if shouldThrowOnAuth {
            throw FakeError.denied
        }
    }

    func fetchSleep(days: Int) async -> [MetricSample] { sleepSamples }
    func fetchHRV(days: Int) async -> [MetricSample] { hrvSamples }
    func fetchSteps(days: Int) async -> [MetricSample] { stepsSamples }
    func fetchRestingHR(days: Int) async -> [MetricSample] { rhrSamples }
    func fetchActiveEnergy(days: Int) async -> [MetricSample] { activeEnergySamples }
    func fetchExerciseTime(days: Int) async -> [MetricSample] { exerciseTimeSamples }
    func fetchDistance(days: Int) async -> [MetricSample] { distanceSamples }
    func fetchVO2Max(days: Int) async -> [MetricSample] { vo2MaxSamples }
    func fetchWalkingHR(days: Int) async -> [MetricSample] { walkingHRSamples }
    func fetchOxygenSaturation(days: Int) async -> [MetricSample] { oxygenSaturationSamples }
    func fetchRespiratoryRate(days: Int) async -> [MetricSample] { respiratoryRateSamples }
    func fetchBodyMass(days: Int) async -> [MetricSample] { bodyMassSamples }

    enum FakeError: Error { case denied }
}

@MainActor
final class FakeCorrelationEngine: CorrelationProviding {
    var cachedResultsByPair: [String: [CorrelationResult]] = [:]
    var runCalledWith: [MetricPair] = []

    func cachedResults(for pairId: String) async -> [CorrelationResult] {
        cachedResultsByPair[pairId] ?? []
    }

    func run(pairs: [MetricPair]) async {
        runCalledWith = pairs
    }
}

@MainActor
final class FakeNarrator: NarrationProviding {
    var narrations: [PatternNarration] = []

    func narrate(results: [CorrelationResult]) async -> [PatternNarration] {
        narrations
    }

    func clearNarrationCache() async {}
}

// makeResult and makeIsolatedCache are provided by TestHelpers.swift

// MARK: - Filter Tests

@Suite("Filter")
struct FilterTests {
    @Test("All filter returns nil pairIds")
    func allFilterReturnsNil() {
        #expect(DiscoveryFeedViewModel.Filter.all.pairIds == nil)
    }

    @Test("Sleep filter returns sleep pairs")
    func sleepFilterReturnsSleepPairs() {
        #expect(DiscoveryFeedViewModel.Filter.sleep.pairIds == ["sleep_hrv", "sleep_rhr", "sleep_walkingHR", "sleep_respiratoryRate", "sleep_spo2"])
    }

    @Test("Steps filter returns steps pairs")
    func stepsFilterReturnsStepsPairs() {
        #expect(DiscoveryFeedViewModel.Filter.steps.pairIds == ["steps_rhr", "steps_hrv", "steps_walkingHR"])
    }

    @Test("Energy filter returns activeEnergy pairs")
    func energyFilterReturnsEnergyPairs() {
        #expect(DiscoveryFeedViewModel.Filter.energy.pairIds == ["activeEnergy_hrv", "activeEnergy_rhr"])
    }

    @Test("Exercise filter returns exerciseTime pairs")
    func exerciseFilterReturnsExercisePairs() {
        #expect(DiscoveryFeedViewModel.Filter.exercise.pairIds == ["exerciseTime_rhr", "exerciseTime_hrv", "exerciseTime_walkingHR"])
    }

    @Test("VO2 Max filter returns vo2Max pairs")
    func vo2MaxFilterReturnsVO2MaxPairs() {
        #expect(DiscoveryFeedViewModel.Filter.vo2Max.pairIds == ["vo2Max_rhr", "vo2Max_hrv", "vo2Max_walkingHR"])
    }

    @Test("Distance filter returns distance pairs")
    func distanceFilterReturnsDistancePairs() {
        #expect(DiscoveryFeedViewModel.Filter.distance.pairIds == ["distance_rhr", "distance_hrv"])
    }

    @Test("Body filter returns bodyMass pairs")
    func bodyFilterReturnsBodyMassPairs() {
        #expect(DiscoveryFeedViewModel.Filter.body.pairIds == ["bodyMass_rhr", "bodyMass_vo2Max"])
    }
}

@Suite("Filtered Items")
struct FilteredItemsTests {
    @Test("All filter returns all items")
    @MainActor func allFilterReturnsAllItems() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let results = [
            makeResult(pairId: "sleep_hrv"),
            makeResult(pairId: "steps_rhr"),
        ]
        vm.items = vm.buildItems(
            from: [results[0]],
            narrations: []
        ) + vm.buildItems(
            from: [results[1]],
            narrations: []
        )
        vm.selectedFilter = .all

        #expect(vm.filteredItems.count == 2)
    }

    @Test("Sleep filter excludes steps_rhr items")
    @MainActor func sleepFilterExcludesSteps() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        vm.items = vm.buildItems(
            from: [makeResult(pairId: "sleep_hrv")],
            narrations: []
        ) + vm.buildItems(
            from: [makeResult(pairId: "steps_rhr")],
            narrations: []
        )
        vm.selectedFilter = .sleep

        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.pairId == "sleep_hrv")
    }

    @Test("Steps filter excludes sleep_hrv items")
    @MainActor func stepsFilterExcludesSleep() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        vm.items = vm.buildItems(
            from: [makeResult(pairId: "sleep_hrv")],
            narrations: []
        ) + vm.buildItems(
            from: [makeResult(pairId: "steps_rhr")],
            narrations: []
        )
        vm.selectedFilter = .steps

        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.pairId == "steps_rhr")
    }
}

// MARK: - buildItems Tests

@Suite("Build Items")
struct BuildItemsTests {
    @Test("buildItems filters out hidden and emerging results")
    @MainActor func filtersNonConfirmedResults() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let results = [
            makeResult(confidence: .hidden),
            makeResult(confidence: .emerging),
        ]

        let items = vm.buildItems(from: results, narrations: [])
        #expect(items.isEmpty)
    }

    @Test("buildItems picks result with highest absolute r")
    @MainActor func picksHighestAbsoluteR() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let results = [
            makeResult(lagHours: 0, r: 0.3, confidence: .high),
            makeResult(lagHours: 24, r: -0.8, confidence: .high),
            makeResult(lagHours: 36, r: 0.5, confidence: .medium),
        ]

        let items = vm.buildItems(from: results, narrations: [])
        #expect(items.count == 1)
        #expect(items.first?.r == -0.8)
        #expect(items.first?.lagHours == 24)
    }

    @Test("buildItems uses narration headline and body when available")
    @MainActor func usesNarration() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let result = makeResult(pairId: "sleep_hrv")
        let narration = PatternNarration(
            pairId: "sleep_hrv",
            headline: "Your HRV Rises After Longer Sleep",
            body: "When you sleep more, HRV goes up.",
            cachedAt: Date()
        )

        let items = vm.buildItems(from: [result], narrations: [narration])
        #expect(items.first?.headline == "Your HRV Rises After Longer Sleep")
        #expect(items.first?.body == "When you sleep more, HRV goes up.")
    }

    @Test("buildItems falls back to pair label when no narration")
    @MainActor func fallsBackWithoutNarration() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let result = makeResult(pairId: "sleep_hrv")

        let items = vm.buildItems(from: [result], narrations: [])
        #expect(items.first?.headline == "SLEEP + HRV")
        #expect(items.first?.body.contains("r=0.71") == true)
    }

    @Test("buildItems sets correct pairLabel")
    @MainActor func correctPairLabel() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )

        let sleepItems = vm.buildItems(from: [makeResult(pairId: "sleep_hrv")], narrations: [])
        #expect(sleepItems.first?.pairLabel == "SLEEP + HRV")

        let stepsItems = vm.buildItems(from: [makeResult(pairId: "steps_rhr")], narrations: [])
        #expect(stepsItems.first?.pairLabel == "STEPS + HR")
    }
}

// MARK: - humanReadablePair Tests

@Suite("Human Readable Pair")
struct HumanReadablePairTests {
    @Test("sleep_hrv maps to SLEEP + HRV")
    @MainActor func sleepHRV() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("sleep_hrv") == "SLEEP + HRV")
    }

    @Test("steps_rhr maps to STEPS + HR")
    @MainActor func stepsRHR() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("steps_rhr") == "STEPS + HR")
    }

    @Test("existing pairs map to correct labels")
    @MainActor func existingPairLabels() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("activeEnergy_hrv") == "ENERGY + HRV")
        #expect(vm.humanReadablePair("exerciseTime_rhr") == "EXERCISE + HR")
        #expect(vm.humanReadablePair("vo2Max_rhr") == "VO2 MAX + HR")
        #expect(vm.humanReadablePair("distance_rhr") == "DISTANCE + HR")
        #expect(vm.humanReadablePair("sleep_rhr") == "SLEEP + HR")
    }

    @Test("new pairs map to correct labels")
    @MainActor func newPairLabels() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("sleep_walkingHR") == "SLEEP + WALKING HR")
        #expect(vm.humanReadablePair("sleep_respiratoryRate") == "SLEEP + RESP. RATE")
        #expect(vm.humanReadablePair("sleep_spo2") == "SLEEP + BLOOD O₂")
        #expect(vm.humanReadablePair("exerciseTime_walkingHR") == "EXERCISE + WALKING HR")
        #expect(vm.humanReadablePair("steps_walkingHR") == "STEPS + WALKING HR")
        #expect(vm.humanReadablePair("bodyMass_rhr") == "BODY MASS + HR")
        #expect(vm.humanReadablePair("bodyMass_vo2Max") == "BODY MASS + VO2 MAX")
        #expect(vm.humanReadablePair("vo2Max_hrv") == "VO2 MAX + HRV")
        #expect(vm.humanReadablePair("vo2Max_walkingHR") == "VO2 MAX + WALKING HR")
        #expect(vm.humanReadablePair("distance_hrv") == "DISTANCE + HRV")
    }

    @Test("unknown pair uppercases the id")
    @MainActor func unknownPair() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("foo_bar") == "FOO_BAR")
    }

    @Test("humanReadablePair resolves labels from v1Pairs shortLabel (no switch statement)")
    @MainActor func resolvesFromV1PairsShortLabel() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        // Verify all 20 v1Pairs return a non-empty label
        for pair in CorrelationEngine.v1Pairs {
            let label = vm.humanReadablePair(pair.id)
            #expect(!label.isEmpty, "pair \(pair.id) returned empty label")
            // Label must equal the shortLabel stored in v1Pairs
            #expect(label == pair.shortLabel, "pair \(pair.id): expected \(pair.shortLabel), got \(label)")
        }
    }
}

// MARK: - Load State Tests

@Suite("Load State Transitions")
struct LoadStateTests {
    @Test("load sets healthKitDenied when authorization throws")
    @MainActor func healthKitDeniedOnThrow() async {
        let fakeHK = FakeHealthKit()
        fakeHK.shouldThrowOnAuth = true
        let vm = DiscoveryFeedViewModel(
            healthKit: fakeHK,
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )

        await vm.load()

        #expect(vm.feedState == .healthKitDenied)
        #expect(vm.loadingPairIds.isEmpty)
    }

    @Test("load sets healthKitDenied when needsAuthorization is true")
    @MainActor func healthKitDeniedOnNeedsAuth() async {
        let fakeHK = FakeHealthKit()
        fakeHK.needsAuthorization = true
        let vm = DiscoveryFeedViewModel(
            healthKit: fakeHK,
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )

        await vm.load()

        #expect(vm.feedState == .healthKitDenied)
    }

    @Test("load sets empty when no patterns found")
    @MainActor func emptyWhenNoPatterns() async {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )

        await vm.load()

        #expect(vm.feedState == .empty)
        #expect(vm.items.isEmpty)
        #expect(vm.loadingPairIds.isEmpty)
    }

    @Test("load sets loaded when cached results exist")
    @MainActor func loadedWithCachedResults() async {
        let fakeEngine = FakeCorrelationEngine()
        fakeEngine.cachedResultsByPair["sleep_hrv"] = [makeResult(pairId: "sleep_hrv")]
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: fakeEngine,
            narrator: FakeNarrator()
        )

        await vm.load()

        #expect(vm.feedState == .loaded)
        #expect(!vm.items.isEmpty)
    }

    @Test("load calls run on engine with metric pairs")
    @MainActor func callsEngineRun() async {
        let fakeEngine = FakeCorrelationEngine()
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: fakeEngine,
            narrator: FakeNarrator()
        )

        await vm.load()

        #expect(fakeEngine.runCalledWith.count == 20)
        #expect(fakeEngine.runCalledWith[0].id == "sleep_hrv")
        #expect(fakeEngine.runCalledWith[1].id == "steps_rhr")
    }

    @Test("initial state is loading")
    @MainActor func initialStateIsLoading() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.feedState == .loading)
        #expect(vm.items.isEmpty)
        #expect(vm.selectedFilter == .all)
    }
}

// MARK: - PatternDetailFormatter Tests

@Suite("PatternDetailFormatter")
struct PatternDetailFormatterTests {
    @Test("effectSizeText returns 'small' for d=0.18")
    func positiveEffect() {
        #expect(PatternDetailFormatter.effectSizeText(0.18) == "small")
    }

    @Test("effectSizeText returns 'negligible' for small d")
    func negativeSmallEffect() {
        #expect(PatternDetailFormatter.effectSizeText(-0.12) == "negligible")
    }

    @Test("effectSizeText returns 'n/a' for nil")
    func nilEffect() {
        #expect(PatternDetailFormatter.effectSizeText(nil) == "n/a")
    }

    @Test("effectSizeText returns 'large' for d >= 0.8")
    func largeEffect() {
        #expect(PatternDetailFormatter.effectSizeText(1.2) == "large")
    }

    @Test("effectSizeText returns 'medium' for 0.5 <= d < 0.8")
    func mediumEffect() {
        #expect(PatternDetailFormatter.effectSizeText(0.6) == "medium")
    }

    @Test("lagText formats hours")
    func lagHours() {
        #expect(PatternDetailFormatter.lagText(36) == "36h")
        #expect(PatternDetailFormatter.lagText(0) == "0h")
    }

    @Test("correlationText formats r value")
    func correlationR() {
        #expect(PatternDetailFormatter.correlationText(0.71) == "r=0.71")
        #expect(PatternDetailFormatter.correlationText(-0.45) == "r=-0.45")
    }
}

// MARK: - Metric Keys & Labels Tests

@Suite("Metric Keys and Labels")
struct MetricKeysTests {
    @Test("metricKeys returns correct keys for sleep_hrv")
    @MainActor func sleepHRVKeys() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let (a, b) = vm.metricKeys(for: "sleep_hrv")
        #expect(a == "sleep")
        #expect(b == "hrv")
    }

    @Test("metricKeys returns correct keys for steps_rhr")
    @MainActor func stepsRHRKeys() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let (a, b) = vm.metricKeys(for: "steps_rhr")
        #expect(a == "steps")
        #expect(b == "rhr")
    }

    @Test("metricKeys returns correct keys for existing pairs")
    @MainActor func existingPairKeys() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let (a1, b1) = vm.metricKeys(for: "activeEnergy_hrv")
        #expect(a1 == "activeEnergy")
        #expect(b1 == "hrv")

        let (a2, b2) = vm.metricKeys(for: "exerciseTime_rhr")
        #expect(a2 == "exerciseTime")
        #expect(b2 == "rhr")

        let (a3, b3) = vm.metricKeys(for: "vo2Max_rhr")
        #expect(a3 == "vo2Max")
        #expect(b3 == "rhr")
    }

    @Test("metricKeys returns correct keys for new pairs")
    @MainActor func newPairKeys() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let (a1, b1) = vm.metricKeys(for: "sleep_walkingHR")
        #expect(a1 == "sleep")
        #expect(b1 == "walkingHR")

        let (a2, b2) = vm.metricKeys(for: "bodyMass_rhr")
        #expect(a2 == "bodyMass")
        #expect(b2 == "rhr")

        let (a3, b3) = vm.metricKeys(for: "vo2Max_walkingHR")
        #expect(a3 == "vo2Max")
        #expect(b3 == "walkingHR")
    }

    @Test("metricLabel returns human-readable labels")
    @MainActor func labels() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.metricLabel("sleep") == "Sleep (hrs)")
        #expect(vm.metricLabel("hrv") == "HRV (ms)")
        #expect(vm.metricLabel("steps") == "Steps")
        #expect(vm.metricLabel("rhr") == "Resting HR (bpm)")
        #expect(vm.metricLabel("activeEnergy") == "Active Energy (kcal)")
        #expect(vm.metricLabel("exerciseTime") == "Exercise (min)")
        #expect(vm.metricLabel("distance") == "Distance (km)")
        #expect(vm.metricLabel("vo2Max") == "VO2 Max (mL/kg/min)")
        #expect(vm.metricLabel("walkingHR") == "Walking HR (bpm)")
        #expect(vm.metricLabel("spo2") == "SpO2 (%)")
        #expect(vm.metricLabel("respiratoryRate") == "Resp. Rate (br/min)")
        #expect(vm.metricLabel("bodyMass") == "Body Mass (kg)")
        #expect(vm.metricLabel("unknown") == "unknown")
    }
}

// MARK: - MetricAlignment Tests

@Suite("Metric Alignment")
struct MetricAlignmentTests {
    @Test("align produces correct points with 0 lag")
    func zeroLag() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let a = [
            MetricSample(date: today, value: 7.5),
            MetricSample(date: yesterday, value: 6.0),
        ]
        let b = [
            MetricSample(date: today, value: 55.0),
            MetricSample(date: yesterday, value: 40.0),
        ]

        let points = MetricAlignment.align(a: a, b: b, lagHours: 0)
        #expect(points.count == 2)
        #expect(points.first?.a == 7.5)
        #expect(points.first?.b == 55.0)
    }

    @Test("align handles 24h lag correctly")
    func dayLag() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let a = [MetricSample(date: yesterday, value: 8.0)]
        let b = [MetricSample(date: today, value: 60.0)]

        let points = MetricAlignment.align(a: a, b: b, lagHours: 24)
        #expect(points.count == 1)
        #expect(points.first?.a == 8.0)
        #expect(points.first?.b == 60.0)
    }

    @Test("align returns empty when no alignment possible")
    func noAlignment() {
        let points = MetricAlignment.align(a: [], b: [], lagHours: 0)
        #expect(points.isEmpty)
    }

    @Test("align handles 12h half-day offset by averaging")
    func halfDayLag() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let a = [MetricSample(date: yesterday, value: 7.0)]
        let b = [
            MetricSample(date: yesterday, value: 40.0),
            MetricSample(date: today, value: 60.0),
        ]

        let points = MetricAlignment.align(a: a, b: b, lagHours: 12)
        #expect(points.count == 1)
        #expect(points.first?.b == 50.0) // (40 + 60) / 2
    }

    @Test("align preserves date from metric A")
    func preservesDate() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let a = [MetricSample(date: today, value: 7.0)]
        let b = [MetricSample(date: today, value: 55.0)]

        let points = MetricAlignment.align(a: a, b: b, lagHours: 0)
        #expect(points.first?.date == today)
    }

    @Test("buildItems includes effectSize and metric labels")
    @MainActor func buildItemsIncludesNewFields() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        let result = makeResult(pairId: "sleep_hrv")
        let items = vm.buildItems(from: [result], narrations: [])

        #expect(items.first?.effectSize == 0.18)
        #expect(items.first?.metricALabel == "Sleep (hrs)")
        #expect(items.first?.metricBLabel == "HRV (ms)")
    }
}
