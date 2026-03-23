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

    func requestAuthorization() async throws {
        if shouldThrowOnAuth {
            throw FakeError.denied
        }
    }

    func fetchSleep(days: Int) async -> [MetricSample] { sleepSamples }
    func fetchHRV(days: Int) async -> [MetricSample] { hrvSamples }
    func fetchSteps(days: Int) async -> [MetricSample] { stepsSamples }
    func fetchRestingHR(days: Int) async -> [MetricSample] { rhrSamples }

    enum FakeError: Error { case denied }
}

@MainActor
final class FakeCorrelationEngine: CorrelationProviding {
    var cachedResultsByPair: [String: [CorrelationResult]] = [:]
    var runCalledWith: [MetricPair] = []

    func cachedResults(for pairId: String) async -> [CorrelationResult] {
        cachedResultsByPair[pairId] ?? []
    }

    func run(pairs: [MetricPair]) {
        runCalledWith = pairs
    }
}

final class FakeNarrator: NarrationProviding, @unchecked Sendable {
    var narrations: [PatternNarration] = []

    func narrate(results: [CorrelationResult]) async -> [PatternNarration] {
        narrations
    }
}

// MARK: - Helper

private func makeResult(
    pairId: String = "sleep_hrv",
    lagHours: Int = 36,
    r: Double = 0.71,
    pValue: Double = 0.003,
    n: Int = 52,
    confidence: CorrelationResult.Confidence = .high
) -> CorrelationResult {
    CorrelationResult(
        pairId: pairId,
        lagHours: lagHours,
        r: r,
        pValue: pValue,
        n: n,
        effectSize: 0.18,
        confidence: confidence,
        computedAt: Date()
    )
}

// MARK: - Filter Tests

@Suite("Filter")
struct FilterTests {
    @Test("All filter returns nil pairIds")
    func allFilterReturnsNil() {
        #expect(DiscoveryFeedViewModel.Filter.all.pairIds == nil)
    }

    @Test("Sleep + HRV filter returns sleep_hrv")
    func sleepHRVFilterReturnsSleepHRV() {
        #expect(DiscoveryFeedViewModel.Filter.sleepHRV.pairIds == ["sleep_hrv"])
    }

    @Test("Steps + HR filter returns steps_rhr")
    func stepsHRFilterReturnsStepsRHR() {
        #expect(DiscoveryFeedViewModel.Filter.stepsHR.pairIds == ["steps_rhr"])
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

    @Test("Sleep+HRV filter excludes steps_rhr items")
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
        vm.selectedFilter = .sleepHRV

        #expect(vm.filteredItems.count == 1)
        #expect(vm.filteredItems.first?.pairId == "sleep_hrv")
    }

    @Test("Steps+HR filter excludes sleep_hrv items")
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
        vm.selectedFilter = .stepsHR

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

    @Test("unknown pair uppercases the id")
    @MainActor func unknownPair() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.humanReadablePair("foo_bar") == "FOO_BAR")
    }
}

// MARK: - lastUpdatedText Tests

@Suite("Last Updated Text")
struct LastUpdatedTextTests {
    @Test("returns nil when lastUpdated is nil")
    @MainActor func nilWhenNoDate() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        #expect(vm.lastUpdatedText == nil)
    }

    @Test("returns non-nil when lastUpdated is set")
    @MainActor func nonNilWhenDateSet() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeHealthKit(),
            engine: FakeCorrelationEngine(),
            narrator: FakeNarrator()
        )
        vm.lastUpdated = Date()
        let text = vm.lastUpdatedText
        #expect(text != nil)
        #expect(text!.starts(with: "Updated"))
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
        #expect(vm.lastUpdated != nil)
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

        #expect(fakeEngine.runCalledWith.count == 2)
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
