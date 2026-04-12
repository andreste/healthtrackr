import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeSample(daysAgo: Int, value: Double) -> MetricSample {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    return MetricSample(date: date, value: value)
}

// MARK: - State Tests

@Suite("HealthMetricsViewModel State")
struct HealthMetricsViewModelStateTests {

    @Test("initial state is loading")
    @MainActor func initialState() {
        let vm = HealthMetricsViewModel(healthKit: FakeHealthKit())
        #expect(vm.state == .loading)
        #expect(vm.snapshots.isEmpty)
    }

    @Test("load sets healthKitDenied when authorization throws")
    @MainActor func authThrows() async {
        let fakeHK = FakeHealthKit()
        fakeHK.shouldThrowOnAuth = true
        let vm = HealthMetricsViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.state == .healthKitDenied)
        #expect(vm.snapshots.isEmpty)
    }

    @Test("load sets healthKitDenied when needsAuthorization is true")
    @MainActor func needsAuthorization() async {
        let fakeHK = FakeHealthKit()
        fakeHK.needsAuthorization = true
        let vm = HealthMetricsViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.state == .healthKitDenied)
    }

    @Test("load sets loaded state after successful fetch")
    @MainActor func loadedState() async {
        let vm = HealthMetricsViewModel(healthKit: FakeHealthKit())
        await vm.load()
        #expect(vm.state == .loaded)
    }

    @Test("loaded snapshots contain all 12 metrics")
    @MainActor func allTwelveMetrics() async {
        let vm = HealthMetricsViewModel(healthKit: FakeHealthKit())
        await vm.load()

        let expectedIds: Set<String> = [
            "sleep", "hrv", "spo2", "respiratoryRate",
            "steps", "activeEnergy", "exerciseTime", "distance",
            "rhr", "walkingHR", "vo2Max", "bodyMass",
        ]
        let actualIds = Set(vm.snapshots.map(\.id))
        #expect(actualIds == expectedIds)
    }
}

// MARK: - Snapshot Computation Tests

@Suite("HealthMetricsViewModel Snapshots")
struct HealthMetricsViewModelSnapshotTests {

    @Test("latestValue is the most recent sample")
    @MainActor func latestValueIsMostRecent() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = [
            makeSample(daysAgo: 2, value: 6.0),
            makeSample(daysAgo: 0, value: 7.5),
            makeSample(daysAgo: 1, value: 6.8),
        ]
        let vm = HealthMetricsViewModel(healthKit: fakeHK)
        await vm.load()

        let sleep = vm.snapshots.first { $0.id == "sleep" }
        #expect(sleep?.latestValue == 7.5)
    }

    @Test("weeklyAverage is mean of all fetched samples")
    @MainActor func weeklyAverageIsMean() async {
        let fakeHK = FakeHealthKit()
        fakeHK.hrvSamples = [
            makeSample(daysAgo: 0, value: 40.0),
            makeSample(daysAgo: 1, value: 50.0),
            makeSample(daysAgo: 2, value: 60.0),
        ]
        let vm = HealthMetricsViewModel(healthKit: fakeHK)
        await vm.load()

        let hrv = vm.snapshots.first { $0.id == "hrv" }
        #expect(hrv?.weeklyAverage == 50.0)
    }

    @Test("latestValue and weeklyAverage are nil when no samples")
    @MainActor func nilWhenNoSamples() async {
        let vm = HealthMetricsViewModel(healthKit: FakeHealthKit())
        await vm.load()

        let sleep = vm.snapshots.first { $0.id == "sleep" }
        #expect(sleep?.latestValue == nil)
        #expect(sleep?.weeklyAverage == nil)
    }

    @Test("SpO2 latestValue is scaled from fraction to percentage")
    @MainActor func spo2ScaledToPercent() async {
        let fakeHK = FakeHealthKit()
        // HealthKit returns SpO2 as a fraction (0.98 = 98%)
        fakeHK.oxygenSaturationSamples = [makeSample(daysAgo: 0, value: 0.98)]
        let vm = HealthMetricsViewModel(healthKit: fakeHK)
        await vm.load()

        let spo2 = vm.snapshots.first { $0.id == "spo2" }
        #expect(abs((spo2?.latestValue ?? 0) - 98.0) < 0.01)
    }

    @Test("SpO2 weeklyAverage is scaled to percentage")
    @MainActor func spo2AverageScaled() async {
        let fakeHK = FakeHealthKit()
        fakeHK.oxygenSaturationSamples = [
            makeSample(daysAgo: 0, value: 0.98),
            makeSample(daysAgo: 1, value: 0.97),
        ]
        let vm = HealthMetricsViewModel(healthKit: fakeHK)
        await vm.load()

        let spo2 = vm.snapshots.first { $0.id == "spo2" }
        #expect(abs((spo2?.weeklyAverage ?? 0) - 97.5) < 0.01)
    }

    @Test("latestDate matches the most recent sample's date")
    @MainActor func latestDateIsMostRecent() async {
        let fakeHK = FakeHealthKit()
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        fakeHK.stepsSamples = [
            MetricSample(date: yesterday, value: 5000),
            MetricSample(date: today, value: 8000),
        ]
        let vm = HealthMetricsViewModel(healthKit: fakeHK)
        await vm.load()

        let steps = vm.snapshots.first { $0.id == "steps" }
        #expect(steps?.latestDate == today)
    }
}

// MARK: - Formatter Tests

@Suite("HealthMetricsFormatter")
struct HealthMetricsFormatterTests {

    private func makeSnapshot(
        id: String = "sleep",
        label: String = "Sleep",
        unit: String = "hrs",
        latestValue: Double? = nil,
        latestDate: Date? = nil,
        weeklyAverage: Double? = nil
    ) -> MetricSnapshot {
        MetricSnapshot(
            id: id,
            label: label,
            unit: unit,
            latestValue: latestValue,
            latestDate: latestDate,
            weeklyAverage: weeklyAverage
        )
    }

    @Test("nil value formats as em dash")
    func nilValueFormatsDash() {
        let s = makeSnapshot(id: "sleep", latestValue: nil)
        #expect(HealthMetricsFormatter.formatValue(s) == "—")
    }

    @Test("sleep formats with 1 decimal")
    func sleepOnedecimal() {
        let s = makeSnapshot(id: "sleep", latestValue: 7.25)
        #expect(HealthMetricsFormatter.formatValue(s) == "7.3")
    }

    @Test("distance formats with 1 decimal")
    func distanceOneDecimal() {
        let s = makeSnapshot(id: "distance", unit: "km", latestValue: 5.2)
        #expect(HealthMetricsFormatter.formatValue(s) == "5.2")
    }

    @Test("hrv formats with 0 decimals")
    func hrvZeroDecimals() {
        let s = makeSnapshot(id: "hrv", unit: "ms", latestValue: 45.7)
        #expect(HealthMetricsFormatter.formatValue(s) == "46")
    }

    @Test("resting HR formats with 0 decimals")
    func rhrZeroDecimals() {
        let s = makeSnapshot(id: "rhr", unit: "bpm", latestValue: 58.4)
        #expect(HealthMetricsFormatter.formatValue(s) == "58")
    }

    @Test("steps formats as integer with grouping separator")
    func stepsGroupingSeparator() {
        let s = makeSnapshot(id: "steps", unit: "steps", latestValue: 8234)
        let result = HealthMetricsFormatter.formatValue(s)
        // Locale-independent: just verify no decimal point and value is present
        #expect(!result.contains("."))
        #expect(result.contains("8") && result.contains("234"))
    }

    @Test("formatRecency returns 'today' for today's date")
    func recencyToday() {
        let today = Date()
        #expect(HealthMetricsFormatter.formatRecency(today) == "today")
    }

    @Test("formatRecency returns 'yest.' for yesterday")
    func recencyYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(HealthMetricsFormatter.formatRecency(yesterday) == "yest.")
    }

    @Test("formatRecency returns days ago for older dates")
    func recencyDaysAgo() {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        #expect(HealthMetricsFormatter.formatRecency(threeDaysAgo) == "3d ago")
    }

    @Test("override value uses the override instead of latestValue")
    func overrideValue() {
        let s = makeSnapshot(id: "sleep", latestValue: 7.0, weeklyAverage: 6.5)
        #expect(HealthMetricsFormatter.formatValue(s, using: 6.5) == "6.5")
    }
}
