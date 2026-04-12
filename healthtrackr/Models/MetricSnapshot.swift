import Foundation

struct MetricSnapshot: Identifiable {
    let id: String
    let label: String
    let unit: String
    let latestValue: Double?
    let latestDate: Date?
    let weeklyAverage: Double?
}
