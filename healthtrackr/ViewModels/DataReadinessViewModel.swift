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
        async let activeEnergyData = healthKit.fetchActiveEnergy(days: 90)
        async let exerciseTimeData = healthKit.fetchExerciseTime(days: 90)
        async let distanceData = healthKit.fetchDistance(days: 90)
        async let vo2MaxData = healthKit.fetchVO2Max(days: 90)

        let sleep = await sleepData
        let hrv = await hrvData
        let steps = await stepsData
        let rhr = await rhrData
        let activeEnergy = await activeEnergyData
        let exerciseTime = await exerciseTimeData
        let distance = await distanceData
        let vo2Max = await vo2MaxData

        let sleepDays = countUniqueDays(sleep)
        let hrvDays = countUniqueDays(hrv)
        let stepsDays = countUniqueDays(steps)
        let rhrDays = countUniqueDays(rhr)
        let activeEnergyDays = countUniqueDays(activeEnergy)
        let exerciseTimeDays = countUniqueDays(exerciseTime)
        let distanceDays = countUniqueDays(distance)
        let vo2MaxDays = countUniqueDays(vo2Max)

        let sleepHrvDays = min(sleepDays, hrvDays)
        let stepsRhrDays = min(stepsDays, rhrDays)
        let sleepRhrDays = min(sleepDays, rhrDays)
        let activeEnergyHrvDays = min(activeEnergyDays, hrvDays)
        let activeEnergyRhrDays = min(activeEnergyDays, rhrDays)
        let exerciseTimeRhrDays = min(exerciseTimeDays, rhrDays)
        let exerciseTimeHrvDays = min(exerciseTimeDays, hrvDays)
        let stepsHrvDays = min(stepsDays, hrvDays)
        let vo2MaxRhrDays = min(vo2MaxDays, rhrDays)
        let distanceRhrDays = min(distanceDays, rhrDays)

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
            MetricStatus(
                id: "sleep_rhr",
                label: "Sleep + HR",
                daysAvailable: sleepRhrDays,
                isReady: sleepRhrDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "activeEnergy_hrv",
                label: "Energy + HRV",
                daysAvailable: activeEnergyHrvDays,
                isReady: activeEnergyHrvDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "activeEnergy_rhr",
                label: "Energy + HR",
                daysAvailable: activeEnergyRhrDays,
                isReady: activeEnergyRhrDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "exerciseTime_rhr",
                label: "Exercise + HR",
                daysAvailable: exerciseTimeRhrDays,
                isReady: exerciseTimeRhrDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "exerciseTime_hrv",
                label: "Exercise + HRV",
                daysAvailable: exerciseTimeHrvDays,
                isReady: exerciseTimeHrvDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "steps_hrv",
                label: "Steps + HRV",
                daysAvailable: stepsHrvDays,
                isReady: stepsHrvDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "vo2Max_rhr",
                label: "VO2 Max + HR",
                daysAvailable: vo2MaxRhrDays,
                isReady: vo2MaxRhrDays >= Self.requiredDays
            ),
            MetricStatus(
                id: "distance_rhr",
                label: "Distance + HR",
                daysAvailable: distanceRhrDays,
                isReady: distanceRhrDays >= Self.requiredDays
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
