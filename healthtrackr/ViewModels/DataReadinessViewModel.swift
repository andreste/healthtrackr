import Foundation

@MainActor @Observable
final class DataReadinessViewModel {
    // MARK: - Metric Row State

    struct MetricStatus: Identifiable {
        let id: String
        let label: String
        let daysAvailable: Int
        let isReady: Bool

        var daysUntilReady: Int {
            max(0, 30 - daysAvailable)
        }
    }

    // MARK: - State

    enum ReadinessState: Equatable {
        case loading
        case loaded
        case healthKitDenied
    }

    var state: ReadinessState = .loading
    var metricStatuses: [MetricStatus] = []

    static let requiredDays = 30

    var canStart: Bool {
        metricStatuses.contains { $0.isReady }
    }

    // MARK: - Dependencies

    private let healthKit: any HealthKitProviding

    init(healthKit: any HealthKitProviding) {
        self.healthKit = healthKit
    }

    convenience init() {
        self.init(healthKit: HealthKitManager())
    }

    // MARK: - Load

    func load() async {
        state = .loading

        do {
            try await healthKit.requestAuthorization()
        } catch {
            state = .healthKitDenied
            return
        }

        if healthKit.needsAuthorization {
            state = .healthKitDenied
            return
        }

        async let sleepData = healthKit.fetchSleep(days: 90)
        async let hrvData = healthKit.fetchHRV(days: 90)
        async let stepsData = healthKit.fetchSteps(days: 90)
        async let rhrData = healthKit.fetchRestingHR(days: 90)

        let sleep = await sleepData
        let hrv = await hrvData
        let steps = await stepsData
        let rhr = await rhrData

        let sleepDays = countUniqueDays(sleep)
        let hrvDays = countUniqueDays(hrv)
        let stepsDays = countUniqueDays(steps)
        let rhrDays = countUniqueDays(rhr)

        let sleepHrvDays = min(sleepDays, hrvDays)
        let stepsRhrDays = min(stepsDays, rhrDays)

        metricStatuses = [
            MetricStatus(
                id: "sleep_hrv",
                label: "Sleep + HRV",
                daysAvailable: sleepHrvDays,
                isReady: sleepHrvDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "steps_rhr",
                label: "Steps + HR",
                daysAvailable: stepsRhrDays,
                isReady: stepsRhrDays >= Self.requiredDays
            ),
        ]

        state = .loaded
    }

    func countUniqueDays(_ samples: [MetricSample]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Set(samples.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
}
