import Foundation

@MainActor @Observable
final class HealthMetricsViewModel {

    // MARK: - State

    enum LoadState: Equatable {
        case loading
        case loaded
        case healthKitDenied
    }

    var state: LoadState = .loading
    var snapshots: [MetricSnapshot] = []

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

        let days = 7

        typealias FetchConfig = (id: String, label: String, unit: String, fetcher: () async -> [MetricSample])

        let configs: [FetchConfig] = [
            ("sleep",          "Sleep",          "hrs",          { [hk = healthKit] in await hk.fetchSleep(days: days) }),
            ("hrv",            "HRV",            "ms",           { [hk = healthKit] in await hk.fetchHRV(days: days) }),
            ("spo2",           "Blood Oxygen",   "%",            { [hk = healthKit] in await hk.fetchOxygenSaturation(days: days) }),
            ("respiratoryRate","Resp. Rate",      "breaths/min",  { [hk = healthKit] in await hk.fetchRespiratoryRate(days: days) }),
            ("steps",          "Steps",          "steps",        { [hk = healthKit] in await hk.fetchSteps(days: days) }),
            ("activeEnergy",   "Active Energy",  "kcal",         { [hk = healthKit] in await hk.fetchActiveEnergy(days: days) }),
            ("exerciseTime",   "Exercise",       "min",          { [hk = healthKit] in await hk.fetchExerciseTime(days: days) }),
            ("distance",       "Distance",       "km",           { [hk = healthKit] in await hk.fetchDistance(days: days) }),
            ("rhr",            "Resting HR",     "bpm",          { [hk = healthKit] in await hk.fetchRestingHR(days: days) }),
            ("walkingHR",      "Walking HR",     "bpm",          { [hk = healthKit] in await hk.fetchWalkingHR(days: days) }),
            ("vo2Max",         "VO2 Max",        "mL/kg·min",    { [hk = healthKit] in await hk.fetchVO2Max(days: days) }),
            ("bodyMass",       "Body Mass",      "kg",           { [hk = healthKit] in await hk.fetchBodyMass(days: days) }),
        ]

        var rawResults: [String: [MetricSample]] = [:]
        await withTaskGroup(of: (String, [MetricSample]).self) { group in
            for config in configs {
                group.addTask { (config.id, await config.fetcher()) }
            }
            for await (id, samples) in group {
                rawResults[id] = samples
            }
        }

        snapshots = configs.map { config in
            var samples = rawResults[config.id] ?? []

            // SpO2 is returned as a fraction (0–1) by HealthKit — scale to percentage
            if config.id == "spo2" {
                samples = samples.map { MetricSample(date: $0.date, value: $0.value * 100) }
            }

            let sorted = samples.sorted { $0.date > $1.date }
            let latest = sorted.first
            let average = sorted.isEmpty ? nil : sorted.reduce(0) { $0 + $1.value } / Double(sorted.count)

            return MetricSnapshot(
                id: config.id,
                label: config.label,
                unit: config.unit,
                latestValue: latest?.value,
                latestDate: latest?.date,
                weeklyAverage: average
            )
        }

        state = .loaded
    }
}
