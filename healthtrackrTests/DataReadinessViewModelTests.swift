import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeSamples(days: Int) -> [MetricSample] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<days).compactMap { offset in
        guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
        return MetricSample(date: date, value: Double.random(in: 1...100))
    }
}

// MARK: - Readiness State Tests

@Suite("Data Readiness States")
struct DataReadinessStateTests {
    @Test("initial state is loading")
    @MainActor func initialState() {
        let vm = DataReadinessViewModel(healthKit: FakeHealthKit())
        #expect(vm.state == .loading)
        #expect(vm.metricStatuses.isEmpty)
        #expect(!vm.canStart)
    }

    @Test("load sets healthKitDenied when authorization throws")
    @MainActor func healthKitDenied() async {
        let fakeHK = FakeHealthKit()
        fakeHK.shouldThrowOnAuth = true
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.state == .healthKitDenied)
        #expect(vm.metricStatuses.isEmpty)
    }

    @Test("load sets healthKitDenied when needsAuthorization is true")
    @MainActor func healthKitNeedsAuth() async {
        let fakeHK = FakeHealthKit()
        fakeHK.needsAuthorization = true
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.state == .healthKitDenied)
    }

    @Test("load sets loaded with metric statuses")
    @MainActor func loadedState() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = makeSamples(days: 45)
        fakeHK.hrvSamples = makeSamples(days: 40)
        fakeHK.stepsSamples = makeSamples(days: 50)
        fakeHK.rhrSamples = makeSamples(days: 35)
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.state == .loaded)
        #expect(vm.metricStatuses.count == 2)
    }
}

// MARK: - Readiness Logic Tests

@Suite("Data Readiness Logic")
struct DataReadinessLogicTests {
    @Test("both pairs ready when all metrics ≥30 days")
    @MainActor func bothPairsReady() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = makeSamples(days: 45)
        fakeHK.hrvSamples = makeSamples(days: 40)
        fakeHK.stepsSamples = makeSamples(days: 50)
        fakeHK.rhrSamples = makeSamples(days: 35)
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.metricStatuses[0].isReady)
        #expect(vm.metricStatuses[1].isReady)
        #expect(vm.canStart)
    }

    @Test("partial readiness — one pair ready, one not")
    @MainActor func partialReadiness() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = makeSamples(days: 45)
        fakeHK.hrvSamples = makeSamples(days: 40)
        fakeHK.stepsSamples = makeSamples(days: 10)
        fakeHK.rhrSamples = makeSamples(days: 50)
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.metricStatuses[0].isReady) // sleep+hrv: min(45,40) = 40 ≥ 30
        #expect(!vm.metricStatuses[1].isReady) // steps+rhr: min(10,50) = 10 < 30
        #expect(vm.canStart) // at least one pair ready
    }

    @Test("no pairs ready when all metrics <30 days")
    @MainActor func noPairsReady() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = makeSamples(days: 10)
        fakeHK.hrvSamples = makeSamples(days: 15)
        fakeHK.stepsSamples = makeSamples(days: 5)
        fakeHK.rhrSamples = makeSamples(days: 20)
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(!vm.metricStatuses[0].isReady) // min(10,15) = 10
        #expect(!vm.metricStatuses[1].isReady) // min(5,20) = 5
        #expect(!vm.canStart)
    }

    @Test("days available uses minimum of pair metrics")
    @MainActor func daysAvailableUsesMin() async {
        let fakeHK = FakeHealthKit()
        fakeHK.sleepSamples = makeSamples(days: 60)
        fakeHK.hrvSamples = makeSamples(days: 25)
        fakeHK.stepsSamples = makeSamples(days: 80)
        fakeHK.rhrSamples = makeSamples(days: 45)
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.metricStatuses[0].daysAvailable == 25) // min(60, 25)
        #expect(vm.metricStatuses[1].daysAvailable == 45) // min(80, 45)
    }

    @Test("daysUntilReady computes correctly")
    func daysUntilReady() {
        let ready = DataReadinessViewModel.MetricStatus(
            id: "test", label: "Test", daysAvailable: 40, isReady: true
        )
        #expect(ready.daysUntilReady == 0)

        let notReady = DataReadinessViewModel.MetricStatus(
            id: "test", label: "Test", daysAvailable: 12, isReady: false
        )
        #expect(notReady.daysUntilReady == 18)
    }

    @Test("empty samples produce 0 days")
    @MainActor func emptySamples() async {
        let fakeHK = FakeHealthKit()
        let vm = DataReadinessViewModel(healthKit: fakeHK)

        await vm.load()

        #expect(vm.metricStatuses[0].daysAvailable == 0)
        #expect(vm.metricStatuses[1].daysAvailable == 0)
        #expect(!vm.canStart)
    }
}

// MARK: - countUniqueDays Tests

@Suite("Count Unique Days")
struct CountUniqueDaysTests {
    @Test("counts unique calendar days correctly")
    @MainActor func uniqueDays() {
        let vm = DataReadinessViewModel(healthKit: FakeHealthKit())
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let samples = [
            MetricSample(date: today, value: 1.0),
            MetricSample(date: today.addingTimeInterval(3600), value: 2.0), // same day
            MetricSample(date: calendar.date(byAdding: .day, value: -1, to: today)!, value: 3.0),
        ]

        #expect(vm.countUniqueDays(samples) == 2)
    }

    @Test("empty samples returns 0")
    @MainActor func emptyReturnsZero() {
        let vm = DataReadinessViewModel(healthKit: FakeHealthKit())
        #expect(vm.countUniqueDays([]) == 0)
    }
}
