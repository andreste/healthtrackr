import Foundation

@MainActor
protocol HealthKitProviding {
    var needsAuthorization: Bool { get }
    func requestAuthorization() async throws
    func fetchSleep(days: Int) async -> [MetricSample]
    func fetchHRV(days: Int) async -> [MetricSample]
    func fetchSteps(days: Int) async -> [MetricSample]
    func fetchRestingHR(days: Int) async -> [MetricSample]
    func fetchActiveEnergy(days: Int) async -> [MetricSample]
    func fetchExerciseTime(days: Int) async -> [MetricSample]
    func fetchDistance(days: Int) async -> [MetricSample]
    func fetchVO2Max(days: Int) async -> [MetricSample]
    func fetchWalkingHR(days: Int) async -> [MetricSample]
    func fetchOxygenSaturation(days: Int) async -> [MetricSample]
    func fetchRespiratoryRate(days: Int) async -> [MetricSample]
    func fetchBodyMass(days: Int) async -> [MetricSample]
}

extension HealthKitManager: HealthKitProviding {}
