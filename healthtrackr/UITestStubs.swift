#if DEBUG
import Foundation

enum UITestArgument {
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting")
    }

    static var skipAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("--skip-auth")
    }

    static var stubEmptyFeed: Bool {
        ProcessInfo.processInfo.arguments.contains("--stub-empty-feed")
    }

    static var healthKitDenied: Bool {
        ProcessInfo.processInfo.arguments.contains("--healthkit-denied")
    }
}

// MARK: - Stub HealthKit

@MainActor
final class StubHealthKit: HealthKitProviding {
    var needsAuthorization: Bool

    private let samples: [MetricSample]

    init(denied: Bool = false) {
        self.needsAuthorization = denied
        if denied {
            self.samples = []
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            self.samples = (0..<60).map { i in
                let date = calendar.date(byAdding: .day, value: -i, to: today)!
                return MetricSample(date: date, value: Double.random(in: 5.0...9.0))
            }
        }
    }

    func requestAuthorization() async throws {
        if needsAuthorization {
            throw StubError.denied
        }
    }

    func fetchSleep(days: Int) async -> [MetricSample] { samples }
    func fetchHRV(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 25...85)) }
    }
    func fetchSteps(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 2000...15000)) }
    }
    func fetchRestingHR(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 55...75)) }
    }
    func fetchActiveEnergy(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 200...800)) }
    }
    func fetchExerciseTime(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 10...90)) }
    }
    func fetchDistance(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 1...12)) }
    }
    func fetchVO2Max(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 30...55)) }
    }
    func fetchWalkingHR(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 90...130)) }
    }
    func fetchOxygenSaturation(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 0.95...0.99)) }
    }
    func fetchRespiratoryRate(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 12...20)) }
    }
    func fetchBodyMass(days: Int) async -> [MetricSample] {
        samples.map { MetricSample(date: $0.date, value: Double.random(in: 60...90)) }
    }

    enum StubError: Error { case denied }
}

// MARK: - Stub Correlation Engine

@MainActor
final class StubCorrelationEngine: CorrelationProviding {
    private let empty: Bool

    init(empty: Bool = false) {
        self.empty = empty
    }

    func cachedResults(for pairId: String) async -> [CorrelationResult] {
        guard !empty else { return [] }
        return [
            CorrelationResult(
                pairId: pairId,
                lagHours: pairId == "sleep_hrv" ? 36 : 24,
                r: pairId == "sleep_hrv" ? 0.71 : -0.45,
                pValue: 0.003,
                n: 52,
                effectSize: pairId == "sleep_hrv" ? 0.18 : -0.12,
                confidence: .high,
                computedAt: Date()
            ),
        ]
    }

    func run(pairs: [MetricPair]) async {}
}

// MARK: - Stub Narrator

final class StubNarrator: NarrationProviding, @unchecked Sendable {
    func narrate(results: [CorrelationResult]) async -> [PatternNarration] {
        results.map { result in
            PatternNarration(
                pairId: result.pairId,
                headline: result.pairId == "sleep_hrv"
                    ? "Your HRV Rises After Longer Sleep"
                    : "Active Days Lower Your Resting Heart Rate",
                body: result.pairId == "sleep_hrv"
                    ? "When you sleep more than 7 hours, your heart rate variability tends to increase the next morning."
                    : "Days with higher step counts are followed by a lower resting heart rate the next day.",
                cachedAt: Date()
            )
        }
    }
}
#endif
