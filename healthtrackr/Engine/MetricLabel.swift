import Foundation

enum MetricLabel {
    static func label(for key: String) -> String {
        switch key {
        case "sleep": return String(localized: "metric.label.sleep", bundle: Bundle.localization)
        case "hrv": return String(localized: "metric.label.hrv", bundle: Bundle.localization)
        case "steps": return String(localized: "metric.label.steps", bundle: Bundle.localization)
        case "rhr": return String(localized: "metric.label.rhr", bundle: Bundle.localization)
        case "activeEnergy": return String(localized: "metric.label.activeEnergy", bundle: Bundle.localization)
        case "exerciseTime": return String(localized: "metric.label.exerciseTime", bundle: Bundle.localization)
        case "distance": return String(localized: "metric.label.distance", bundle: Bundle.localization)
        case "vo2Max": return String(localized: "metric.label.vo2Max", bundle: Bundle.localization)
        case "walkingHR": return String(localized: "metric.label.walkingHR", bundle: Bundle.localization)
        case "spo2": return String(localized: "metric.label.spo2", bundle: Bundle.localization)
        case "respiratoryRate": return String(localized: "metric.label.respiratoryRate", bundle: Bundle.localization)
        case "bodyMass": return String(localized: "metric.label.bodyMass", bundle: Bundle.localization)
        default: return key
        }
    }
}
