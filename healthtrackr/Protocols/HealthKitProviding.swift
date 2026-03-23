import Foundation

@MainActor
protocol HealthKitProviding {
    var needsAuthorization: Bool { get }
    func requestAuthorization() async throws
    func fetchSleep(days: Int) async -> [MetricSample]
    func fetchHRV(days: Int) async -> [MetricSample]
    func fetchSteps(days: Int) async -> [MetricSample]
    func fetchRestingHR(days: Int) async -> [MetricSample]
}

extension HealthKitManager: HealthKitProviding {}
