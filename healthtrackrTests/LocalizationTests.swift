import Foundation
import Testing
@testable import healthtrackr

/// Tests that verify the localization infrastructure is wired up correctly.
/// These tests use `Bundle.localization` (which resolves to the app bundle via
/// `BundleLocator`) so they exercise the exact same lookup path as production code.
@Suite("Localization")
struct LocalizationTests {

    // MARK: - Bundle resolution

    @Test("Bundle.localization resolves the app bundle containing localized strings")
    func bundleLocalizationResolvesAppBundle() {
        // The xcstrings source file is compiled into Localizable.strings inside each
        // .lproj directory at build time. Verify at least the English string table exists.
        let url = Bundle.localization.url(
            forResource: "Localizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: "en"
        )
        #expect(url != nil, "Localizable.strings (en) should be found in Bundle.localization")
    }

    // MARK: - HealthMetricsFormatter

    @Test("formatRecency returns 'today' for today")
    func recencyToday() {
        let result = HealthMetricsFormatter.formatRecency(Date())
        #expect(result == "today")
    }

    @Test("formatRecency returns 'yest.' for yesterday")
    func recencyYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let result = HealthMetricsFormatter.formatRecency(yesterday)
        #expect(result == "yest.")
    }

    @Test("formatRecency returns '<n>d ago' for older dates")
    func recencyOlderDate() {
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let result = HealthMetricsFormatter.formatRecency(oldDate)
        #expect(result == "5d ago")
    }

    @Test("accessibilityLabel with no data returns non-empty string")
    func accessibilityLabelNoData() {
        let snapshot = MetricSnapshot(
            id: "sleep",
            label: "Sleep",
            unit: "hrs",
            latestValue: nil,
            latestDate: nil,
            weeklyAverage: nil
        )
        let result = HealthMetricsFormatter.accessibilityLabel(snapshot)
        #expect(!result.isEmpty)
        #expect(result.contains("Sleep"))
    }

    // MARK: - PatternDetailFormatter

    @Test("effectSizeText returns non-empty strings for all thresholds")
    func effectSizeTextNonEmpty() {
        #expect(!PatternDetailFormatter.effectSizeText(nil).isEmpty)
        #expect(!PatternDetailFormatter.effectSizeText(0.0).isEmpty)
        #expect(!PatternDetailFormatter.effectSizeText(0.3).isEmpty)
        #expect(!PatternDetailFormatter.effectSizeText(0.6).isEmpty)
        #expect(!PatternDetailFormatter.effectSizeText(1.0).isEmpty)
    }

    @Test("effectSizeText returns distinct values for each threshold")
    func effectSizeTextDistinct() {
        let naValue = PatternDetailFormatter.effectSizeText(nil)
        let negligible = PatternDetailFormatter.effectSizeText(0.1)
        let small = PatternDetailFormatter.effectSizeText(0.3)
        let medium = PatternDetailFormatter.effectSizeText(0.6)
        let large = PatternDetailFormatter.effectSizeText(1.0)

        let values = [naValue, negligible, small, medium, large]
        let unique = Set(values)
        #expect(unique.count == 5, "Each effect size threshold should produce a distinct label")
    }

    // MARK: - MetricLabel

    @Test("MetricLabel.label returns non-empty string for all known keys")
    func metricLabelNonEmpty() {
        let keys = ["sleep", "hrv", "steps", "rhr", "activeEnergy",
                    "exerciseTime", "distance", "vo2Max", "walkingHR",
                    "spo2", "respiratoryRate", "bodyMass"]
        for key in keys {
            let label = MetricLabel.label(for: key)
            #expect(!label.isEmpty, "MetricLabel.label(for: \"\(key)\") should return a non-empty string")
        }
    }

    @Test("MetricLabel.label returns the key itself for unknown keys")
    func metricLabelUnknownKey() {
        #expect(MetricLabel.label(for: "unknownKey") == "unknownKey")
    }

    @Test("MetricLabel.label returns distinct values for each key")
    func metricLabelDistinct() {
        let keys = ["sleep", "hrv", "steps", "rhr", "activeEnergy",
                    "exerciseTime", "distance", "vo2Max", "walkingHR",
                    "spo2", "respiratoryRate", "bodyMass"]
        let labels = keys.map { MetricLabel.label(for: $0) }
        let unique = Set(labels)
        #expect(unique.count == keys.count, "Each metric key should produce a distinct label")
    }

    @Test("MetricLabel.label returns expected English values for smoke-test keys")
    func metricLabelEnglishValues() {
        #expect(MetricLabel.label(for: "sleep") == "Sleep (hrs)")
        #expect(MetricLabel.label(for: "hrv") == "HRV (ms)")
        #expect(MetricLabel.label(for: "steps") == "Steps")
        #expect(MetricLabel.label(for: "rhr") == "Resting HR (bpm)")
    }

    // MARK: - HealthPermissionItem

    @Test("all HealthPermissionItem labels are non-empty strings")
    func permissionItemLabelsNonEmpty() {
        for item in HealthPermissionItem.all {
            #expect(!item.label.isEmpty, "label for id '\(item.id)' should not be empty")
        }
    }

    @Test("fallback body text contains correlation value")
    @MainActor func fallbackBodyContainsCorrelation() {
        let vm = DiscoveryFeedViewModel(
            healthKit: FakeLocalizationHealthKit(),
            engine: FakeLocalizationEngine(),
            narrator: FakeLocalizationNarrator()
        )
        let result = vm.buildItems(
            from: [makeLocalizationResult(pairId: "sleep_hrv", r: 0.71)],
            narrations: []
        )
        #expect(result.first?.body.contains("0.71") == true)
    }
}

// MARK: - Minimal fakes for localization tests

@MainActor
private final class FakeLocalizationHealthKit: HealthKitProviding {
    var needsAuthorization = false
    var isAlreadyAuthorized: Bool { true }
    func requestAuthorization() async throws {}
    func fetchSleep(days: Int) async -> [MetricSample] { [] }
    func fetchHRV(days: Int) async -> [MetricSample] { [] }
    func fetchSteps(days: Int) async -> [MetricSample] { [] }
    func fetchRestingHR(days: Int) async -> [MetricSample] { [] }
    func fetchActiveEnergy(days: Int) async -> [MetricSample] { [] }
    func fetchExerciseTime(days: Int) async -> [MetricSample] { [] }
    func fetchDistance(days: Int) async -> [MetricSample] { [] }
    func fetchVO2Max(days: Int) async -> [MetricSample] { [] }
    func fetchWalkingHR(days: Int) async -> [MetricSample] { [] }
    func fetchOxygenSaturation(days: Int) async -> [MetricSample] { [] }
    func fetchRespiratoryRate(days: Int) async -> [MetricSample] { [] }
    func fetchBodyMass(days: Int) async -> [MetricSample] { [] }
}

@MainActor
private final class FakeLocalizationEngine: CorrelationProviding {
    func cachedResults(for pairId: String) async -> [CorrelationResult] { [] }
    func run(pairs: [MetricPair]) async {}
}

@MainActor
private final class FakeLocalizationNarrator: NarrationProviding {
    func narrate(results: [CorrelationResult]) async -> [PatternNarration] { [] }
    func clearNarrationCache() async {}
}

private func makeLocalizationResult(
    pairId: String = "sleep_hrv",
    r: Double = 0.71
) -> CorrelationResult {
    CorrelationResult(
        pairId: pairId,
        lagHours: 0,
        r: r,
        pValue: 0.01,
        n: 30,
        effectSize: 0.18,
        confidence: .high,
        computedAt: Date()
    )
}
