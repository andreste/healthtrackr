import Foundation

enum AnalyticsEvent {
    // Onboarding
    case onboardingCompleted
    case healthKitPermissionGranted
    case healthKitPermissionDenied
    case healthKitPermissionsViewed
    case healthKitPermissionRequested

    // Authentication
    case signedIn
    case signedOut
    case signInViewed
    case signInTapped
    case signInFailed(reason: String)

    // Feed
    case feedViewed
    case feedLoadFailed
    case feedFilterChanged(filter: String)
    case patternCardTapped(pairId: String)
    case feedFooterViewed

    // Pattern Detail
    case metricDetailViewed(metricId: String)
    case correlationViewed(metricId: String)
    case patternDetailChartTapped(pairId: String)

    // Settings
    case settingsOpened
    case settingsAPIKeySaved
    case settingsAPIKeyRemoved
    case settingsHealthAppOpened

    // Health Metrics
    case healthMetricsViewed

    var name: String {
        switch self {
        // Onboarding
        case .onboardingCompleted:           return "Onboarding Completed"
        case .healthKitPermissionGranted:    return "HealthKit Permission Granted"
        case .healthKitPermissionDenied:     return "HealthKit Permission Denied"
        case .healthKitPermissionsViewed:    return "HealthKit Permissions Viewed"
        case .healthKitPermissionRequested:  return "HealthKit Permission Requested"

        // Authentication
        case .signedIn:                      return "Signed In"
        case .signedOut:                     return "Signed Out"
        case .signInViewed:                  return "Sign In Viewed"
        case .signInTapped:                  return "Sign In Tapped"
        case .signInFailed:                  return "Sign In Failed"

        // Feed
        case .feedViewed:                    return "Feed Viewed"
        case .feedLoadFailed:                return "Feed Load Failed"
        case .feedFilterChanged:             return "Feed Filter Changed"
        case .patternCardTapped:             return "Pattern Card Tapped"
        case .feedFooterViewed:              return "Feed Footer Viewed"

        // Pattern Detail
        case .metricDetailViewed:            return "Metric Detail Viewed"
        case .correlationViewed:             return "Correlation Viewed"
        case .patternDetailChartTapped:      return "Pattern Detail Chart Tapped"

        // Settings
        case .settingsOpened:                return "Settings Opened"
        case .settingsAPIKeySaved:           return "Settings API Key Saved"
        case .settingsAPIKeyRemoved:         return "Settings API Key Removed"
        case .settingsHealthAppOpened:       return "Settings Health App Opened"

        // Health Metrics
        case .healthMetricsViewed:           return "Health Metrics Viewed"
        }
    }

    var properties: [String: String] {
        switch self {
        case .metricDetailViewed(let metricId):       return ["metric_id": metricId]
        case .correlationViewed(let metricId):         return ["metric_id": metricId]
        case .patternCardTapped(let pairId):           return ["pair_id": pairId]
        case .patternDetailChartTapped(let pairId):    return ["pair_id": pairId]
        case .feedFilterChanged(let filter):           return ["filter": filter]
        case .signInFailed(let reason):                return ["reason": reason]
        default:                                       return [:]
        }
    }
}
