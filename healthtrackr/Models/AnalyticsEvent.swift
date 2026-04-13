import Foundation

enum AnalyticsEvent {
    case onboardingCompleted
    case healthKitPermissionGranted
    case healthKitPermissionDenied
    case feedViewed
    case metricDetailViewed(metricId: String)
    case correlationViewed(metricId: String)
    case settingsOpened
    case signedIn
    case signedOut

    var name: String {
        switch self {
        case .onboardingCompleted:        return "Onboarding Completed"
        case .healthKitPermissionGranted: return "HealthKit Permission Granted"
        case .healthKitPermissionDenied:  return "HealthKit Permission Denied"
        case .feedViewed:                 return "Feed Viewed"
        case .metricDetailViewed:         return "Metric Detail Viewed"
        case .correlationViewed:          return "Correlation Viewed"
        case .settingsOpened:             return "Settings Opened"
        case .signedIn:                   return "Signed In"
        case .signedOut:                  return "Signed Out"
        }
    }

    var properties: [String: String] {
        switch self {
        case .metricDetailViewed(let metricId): return ["metric_id": metricId]
        case .correlationViewed(let metricId):  return ["metric_id": metricId]
        default:                                return [:]
        }
    }
}
