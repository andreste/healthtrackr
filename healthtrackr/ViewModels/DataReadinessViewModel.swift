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

        if healthKit.needsAuthorization {
            state = .healthKitDenied
            return
        }

        let fetchMap: [String: () async -> [MetricSample]] = [
            "sleep": { [hk = self.healthKit] in await hk.fetchSleep(days: 90) },
            "hrv": { [hk = self.healthKit] in await hk.fetchHRV(days: 90) },
            "steps": { [hk = self.healthKit] in await hk.fetchSteps(days: 90) },
            "rhr": { [hk = self.healthKit] in await hk.fetchRestingHR(days: 90) },
            "activeEnergy": { [hk = self.healthKit] in await hk.fetchActiveEnergy(days: 90) },
            "exerciseTime": { [hk = self.healthKit] in await hk.fetchExerciseTime(days: 90) },
            "distance": { [hk = self.healthKit] in await hk.fetchDistance(days: 90) },
            "vo2Max": { [hk = self.healthKit] in await hk.fetchVO2Max(days: 90) },
            "walkingHR": { [hk = self.healthKit] in await hk.fetchWalkingHR(days: 90) },
            "spo2": { [hk = self.healthKit] in await hk.fetchOxygenSaturation(days: 90) },
            "respiratoryRate": { [hk = self.healthKit] in await hk.fetchRespiratoryRate(days: 90) },
            "bodyMass": { [hk = self.healthKit] in await hk.fetchBodyMass(days: 90) },
        ]

        let metricDisplayNames: [String: String] = [
            "sleep": "Sleep",
            "hrv": "HRV",
            "steps": "Steps",
            "rhr": "HR",
            "activeEnergy": "Energy",
            "exerciseTime": "Exercise",
            "distance": "Distance",
            "vo2Max": "VO2 Max",
            "walkingHR": "Walking HR",
            "spo2": "SpO2",
            "respiratoryRate": "Resp. Rate",
            "bodyMass": "Body Mass",
        ]

        let uniqueKeys = Set(CorrelationEngine.v1Pairs.flatMap { [$0.metricAKey, $0.metricBKey] })

        var dayCounts: [String: Int] = [:]
        await withTaskGroup(of: (String, Int).self) { group in
            for key in uniqueKeys {
                guard let fetcher = fetchMap[key] else { continue }
                group.addTask {
                    let samples = await fetcher()
                    return (key, self.countUniqueDays(samples))
                }
            }
            for await (key, count) in group {
                dayCounts[key] = count
            }
        }

        metricStatuses = CorrelationEngine.v1Pairs.map { pair in
            let aDays = dayCounts[pair.metricAKey] ?? 0
            let bDays = dayCounts[pair.metricBKey] ?? 0
            let days = min(aDays, bDays)
            let labelA = metricDisplayNames[pair.metricAKey] ?? pair.metricAKey
            let labelB = metricDisplayNames[pair.metricBKey] ?? pair.metricBKey
            return MetricStatus(
                id: pair.id,
                label: "\(labelA) + \(labelB)",
                daysAvailable: days,
                isReady: days >= Self.requiredDays
            )
        }

        state = .loaded
    }

    nonisolated func countUniqueDays(_ samples: [MetricSample]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Set(samples.map { calendar.startOfDay(for: $0.date) })
        return uniqueDays.count
    }
}
