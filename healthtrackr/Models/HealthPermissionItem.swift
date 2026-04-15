import Foundation

/// Represents a single HealthKit permission displayed in the settings sheet.
struct HealthPermissionItem: Identifiable {
    let id: String
    let icon: String
    let label: String
}

extension HealthPermissionItem {
    /// All HealthKit permissions the app requests, in display order.
    static var all: [HealthPermissionItem] {
        [
            HealthPermissionItem(id: "sleep",          icon: "bed.double.fill",      label: String(localized: "Sleep Analysis",              bundle: Bundle.localization)),
            HealthPermissionItem(id: "hrv",             icon: "waveform.path.ecg",    label: String(localized: "Heart Rate Variability",      bundle: Bundle.localization)),
            HealthPermissionItem(id: "steps",           icon: "figure.walk",          label: String(localized: "Steps",                       bundle: Bundle.localization)),
            HealthPermissionItem(id: "rhr",             icon: "heart.fill",           label: String(localized: "Resting heart rate",           bundle: Bundle.localization)),
            HealthPermissionItem(id: "activeEnergy",    icon: "flame.fill",           label: String(localized: "Active energy",                bundle: Bundle.localization)),
            HealthPermissionItem(id: "exerciseTime",    icon: "figure.run",           label: String(localized: "Exercise time",                bundle: Bundle.localization)),
            HealthPermissionItem(id: "distance",        icon: "map.fill",             label: String(localized: "Walking + Running Distance",   bundle: Bundle.localization)),
            HealthPermissionItem(id: "vo2Max",          icon: "lungs.fill",           label: String(localized: "VO2 Max (mL/kg/min)",          bundle: Bundle.localization)),
            HealthPermissionItem(id: "walkingHR",       icon: "figure.walk.motion",   label: String(localized: "Walking heart rate",           bundle: Bundle.localization)),
            HealthPermissionItem(id: "bloodOxygen",     icon: "drop.circle.fill",     label: String(localized: "Blood oxygen",                 bundle: Bundle.localization)),
            HealthPermissionItem(id: "respiratoryRate", icon: "wind",                 label: String(localized: "Respiratory rate",             bundle: Bundle.localization)),
            HealthPermissionItem(id: "bodyMass",        icon: "scalemass.fill",       label: String(localized: "Body mass",                   bundle: Bundle.localization)),
        ]
    }
}
