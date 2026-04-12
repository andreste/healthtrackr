import Foundation

/// Represents a single HealthKit permission displayed in the settings sheet.
struct HealthPermissionItem: Identifiable {
    let id: String
    let icon: String
    let label: String
}

extension HealthPermissionItem {
    /// All HealthKit permissions the app requests, in display order.
    static let all: [HealthPermissionItem] = [
        HealthPermissionItem(id: "sleep",          icon: "bed.double.fill",      label: "Sleep Analysis"),
        HealthPermissionItem(id: "hrv",             icon: "waveform.path.ecg",    label: "Heart Rate Variability"),
        HealthPermissionItem(id: "steps",           icon: "figure.walk",          label: "Steps"),
        HealthPermissionItem(id: "rhr",             icon: "heart.fill",           label: "Resting Heart Rate"),
        HealthPermissionItem(id: "activeEnergy",    icon: "flame.fill",           label: "Active Energy"),
        HealthPermissionItem(id: "exerciseTime",    icon: "figure.run",           label: "Exercise Time"),
        HealthPermissionItem(id: "distance",        icon: "map.fill",             label: "Walking + Running Distance"),
        HealthPermissionItem(id: "vo2Max",          icon: "lungs.fill",           label: "VO2 Max"),
        HealthPermissionItem(id: "walkingHR",       icon: "figure.walk.motion",   label: "Walking Heart Rate"),
        HealthPermissionItem(id: "bloodOxygen",     icon: "drop.circle.fill",     label: "Blood Oxygen"),
        HealthPermissionItem(id: "respiratoryRate", icon: "wind",                 label: "Respiratory Rate"),
        HealthPermissionItem(id: "bodyMass",        icon: "scalemass.fill",       label: "Body Mass"),
    ]
}
