import Foundation

enum HealthMetricsFormatter {

    static func formatValue(_ snapshot: MetricSnapshot, using value: Double? = nil) -> String {
        guard let v = value ?? snapshot.latestValue else { return "—" }
        switch snapshot.id {
        case "sleep", "distance", "vo2Max", "bodyMass":
            return String(format: "%.1f", v)
        case "spo2":
            return String(format: "%.1f", v)
        case "steps", "activeEnergy", "exerciseTime":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: v)) ?? String(format: "%.0f", v)
        default: // hrv, rhr, walkingHR, respiratoryRate
            return String(format: "%.0f", v)
        }
    }

    static func formatRecency(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return String(localized: "recency.today", bundle: Bundle.localization)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "recency.yesterday", bundle: Bundle.localization)
        }
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        let daysString = "\(days)d"
        let format = String(localized: "%@ ago", bundle: Bundle.localization)
        return String(format: format, daysString)
    }

    static func accessibilityLabel(_ snapshot: MetricSnapshot) -> String {
        let value = formatValue(snapshot)
        let unit = snapshot.latestValue != nil ? snapshot.unit : ""
        if let date = snapshot.latestDate {
            return "\(snapshot.label): \(value) \(unit), \(formatRecency(date))"
        }
        return "\(snapshot.label): \(String(localized: "no.data", bundle: Bundle.localization))"
    }
}
