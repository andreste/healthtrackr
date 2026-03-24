import HealthKit

@MainActor
final class HealthKitManager {
    private let store = HKHealthStore()

    var needsAuthorization = false

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .stepCount,
            .restingHeartRate,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning,
            .vo2Max,
            .walkingHeartRateAverage,
            .oxygenSaturation,
            .respiratoryRate,
            .bodyMass,
        ]
        for identifier in quantityIdentifiers {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        return types
    }()

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            needsAuthorization = true
            return
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        needsAuthorization = false
    }

    // MARK: - Sleep (sum of .asleep intervals per day)

    func fetchSleep(days: Int = 90) async -> [MetricSample] {
        guard let sampleType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let asleepValues: Set<HKCategoryValueSleepAnalysis> = [
            .asleepUnspecified,
            .asleepCore,
            .asleepDeep,
            .asleepREM,
        ]
        let asleepPredicate = HKCategoryValueSleepAnalysis.predicateForSamples(
            equalTo: asleepValues
        )
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, asleepPredicate])

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        var dailyTotals: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
            dailyTotals[day, default: 0] += hours
        }

        return dailyTotals.map { MetricSample(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - HRV (morning 5-9am average per day)

    func fetchHRV(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }

        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: datePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        // Filter to 5-9am morning window
        var dailySums: [Date: Double] = [:]
        var dailyCounts: [Date: Int] = [:]

        for sample in samples {
            let hour = calendar.component(.hour, from: sample.startDate)
            guard hour >= 5 && hour < 9 else { continue }

            let day = calendar.startOfDay(for: sample.startDate)
            let ms = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            dailySums[day, default: 0] += ms
            dailyCounts[day, default: 0] += 1
        }

        return dailySums.compactMap { day, sum in
            guard let count = dailyCounts[day], count > 0 else { return nil }
            return MetricSample(date: day, value: sum / Double(count))
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Steps (daily sum)

    func fetchSteps(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.count(),
            options: .cumulativeSum,
            days: days
        )
    }

    // MARK: - Resting Heart Rate (daily average)

    func fetchRestingHR(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit(from: "count/min"),
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Active Energy Burned (daily sum, kcal)

    func fetchActiveEnergy(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.kilocalorie(),
            options: .cumulativeSum,
            days: days
        )
    }

    // MARK: - Exercise Time (daily sum, minutes)

    func fetchExerciseTime(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.minute(),
            options: .cumulativeSum,
            days: days
        )
    }

    // MARK: - Walking + Running Distance (daily sum, km)

    func fetchDistance(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.meterUnit(with: .kilo),
            options: .cumulativeSum,
            days: days
        )
    }

    // MARK: - VO2 Max (daily average, mL/kg/min)

    func fetchVO2Max(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            return []
        }
        let unit = HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: unit,
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Walking Heart Rate Average (daily average, bpm)

    func fetchWalkingHR(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit(from: "count/min"),
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Oxygen Saturation (daily average, %)

    func fetchOxygenSaturation(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.percent(),
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Respiratory Rate (daily average, breaths/min)

    func fetchRespiratoryRate(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit(from: "count/min"),
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Body Mass (daily average, kg)

    func fetchBodyMass(days: Int = 90) async -> [MetricSample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return []
        }
        return await fetchStatisticsCollection(
            quantityType: quantityType,
            unit: HKUnit.gramUnit(with: .kilo),
            options: .discreteAverage,
            days: days
        )
    }

    // MARK: - Shared Statistics Collection Helper

    private func fetchStatisticsCollection(
        quantityType: HKQuantityType,
        unit: HKUnit,
        options: HKStatisticsOptions,
        days: Int
    ) async -> [MetricSample] {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return []
        }
        let anchorDate = calendar.startOfDay(for: endDate)
        let interval = DateComponents(day: 1)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, _ in
                guard let collection else {
                    continuation.resume(returning: [])
                    return
                }

                var samples: [MetricSample] = []
                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value: Double?
                    if options.contains(.cumulativeSum) {
                        value = statistics.sumQuantity()?.doubleValue(for: unit)
                    } else {
                        value = statistics.averageQuantity()?.doubleValue(for: unit)
                    }
                    if let value {
                        samples.append(MetricSample(date: statistics.startDate, value: value))
                    }
                }
                continuation.resume(returning: samples)
            }

            store.execute(query)
        }
    }
}
