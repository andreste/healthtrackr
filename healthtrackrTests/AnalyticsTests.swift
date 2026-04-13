import Foundation
import Testing
@testable import healthtrackr

// MARK: - Fake

@MainActor
final class FakeAnalyticsProvider: AnalyticsProviding {
    private(set) var trackedEvents: [AnalyticsEvent] = []
    private(set) var identifiedUserId: String?
    private(set) var identifiedProperties: [String: String] = [:]

    func track(event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func identify(userId: String, properties: [String: String]) {
        identifiedUserId = userId
        identifiedProperties = properties
    }
}

// MARK: - Event Name Tests

@Suite("AnalyticsEvent names")
struct AnalyticsEventNameTests {

    // MARK: Onboarding

    @Test("onboardingCompleted has correct name")
    func onboardingCompletedName() {
        #expect(AnalyticsEvent.onboardingCompleted.name == "Onboarding Completed")
    }

    @Test("healthKitPermissionGranted has correct name")
    func healthKitGrantedName() {
        #expect(AnalyticsEvent.healthKitPermissionGranted.name == "HealthKit Permission Granted")
    }

    @Test("healthKitPermissionDenied has correct name")
    func healthKitDeniedName() {
        #expect(AnalyticsEvent.healthKitPermissionDenied.name == "HealthKit Permission Denied")
    }

    @Test("healthKitPermissionsViewed has correct name")
    func healthKitPermissionsViewedName() {
        #expect(AnalyticsEvent.healthKitPermissionsViewed.name == "HealthKit Permissions Viewed")
    }

    @Test("healthKitPermissionRequested has correct name")
    func healthKitPermissionRequestedName() {
        #expect(AnalyticsEvent.healthKitPermissionRequested.name == "HealthKit Permission Requested")
    }

    // MARK: Authentication

    @Test("signedIn has correct name")
    func signedInName() {
        #expect(AnalyticsEvent.signedIn.name == "Signed In")
    }

    @Test("signedOut has correct name")
    func signedOutName() {
        #expect(AnalyticsEvent.signedOut.name == "Signed Out")
    }

    @Test("signInViewed has correct name")
    func signInViewedName() {
        #expect(AnalyticsEvent.signInViewed.name == "Sign In Viewed")
    }

    @Test("signInTapped has correct name")
    func signInTappedName() {
        #expect(AnalyticsEvent.signInTapped.name == "Sign In Tapped")
    }

    @Test("signInFailed has correct name and carries reason")
    func signInFailedProperties() {
        let event = AnalyticsEvent.signInFailed(reason: "network error")
        #expect(event.name == "Sign In Failed")
        #expect(event.properties["reason"] == "network error")
    }

    // MARK: Feed

    @Test("feedViewed has correct name")
    func feedViewedName() {
        #expect(AnalyticsEvent.feedViewed.name == "Feed Viewed")
    }

    @Test("feedLoadFailed has correct name")
    func feedLoadFailedName() {
        #expect(AnalyticsEvent.feedLoadFailed.name == "Feed Load Failed")
    }

    @Test("feedFilterChanged has correct name and carries filter")
    func feedFilterChangedProperties() {
        let event = AnalyticsEvent.feedFilterChanged(filter: "Sleep")
        #expect(event.name == "Feed Filter Changed")
        #expect(event.properties["filter"] == "Sleep")
    }

    @Test("patternCardTapped has correct name and carries pairId")
    func patternCardTappedProperties() {
        let event = AnalyticsEvent.patternCardTapped(pairId: "sleep_hrv")
        #expect(event.name == "Pattern Card Tapped")
        #expect(event.properties["pair_id"] == "sleep_hrv")
    }

    // MARK: Pattern Detail

    @Test("metricDetailViewed carries metricId in properties")
    func metricDetailViewedProperties() {
        let event = AnalyticsEvent.metricDetailViewed(metricId: "sleep_hrv")
        #expect(event.name == "Metric Detail Viewed")
        #expect(event.properties["metric_id"] == "sleep_hrv")
    }

    @Test("correlationViewed carries metricId in properties")
    func correlationViewedProperties() {
        let event = AnalyticsEvent.correlationViewed(metricId: "steps_energy")
        #expect(event.name == "Correlation Viewed")
        #expect(event.properties["metric_id"] == "steps_energy")
    }

    @Test("patternDetailChartTapped has correct name and carries pairId")
    func patternDetailChartTappedProperties() {
        let event = AnalyticsEvent.patternDetailChartTapped(pairId: "steps_rhr")
        #expect(event.name == "Pattern Detail Chart Tapped")
        #expect(event.properties["pair_id"] == "steps_rhr")
    }

    // MARK: Settings

    @Test("settingsOpened has correct name")
    func settingsOpenedName() {
        #expect(AnalyticsEvent.settingsOpened.name == "Settings Opened")
    }

    @Test("settingsAPIKeySaved has correct name")
    func settingsAPIKeySavedName() {
        #expect(AnalyticsEvent.settingsAPIKeySaved.name == "Settings API Key Saved")
    }

    @Test("settingsAPIKeyRemoved has correct name")
    func settingsAPIKeyRemovedName() {
        #expect(AnalyticsEvent.settingsAPIKeyRemoved.name == "Settings API Key Removed")
    }

    @Test("settingsHealthAppOpened has correct name")
    func settingsHealthAppOpenedName() {
        #expect(AnalyticsEvent.settingsHealthAppOpened.name == "Settings Health App Opened")
    }

    // MARK: Health Metrics

    @Test("healthMetricsViewed has correct name")
    func healthMetricsViewedName() {
        #expect(AnalyticsEvent.healthMetricsViewed.name == "Health Metrics Viewed")
    }

    // MARK: Empty properties

    @Test("events without payload have empty properties")
    func noPayloadEventsHaveEmptyProperties() {
        let noPayloadEvents: [AnalyticsEvent] = [
            .onboardingCompleted,
            .healthKitPermissionGranted,
            .healthKitPermissionDenied,
            .healthKitPermissionsViewed,
            .healthKitPermissionRequested,
            .feedViewed,
            .feedLoadFailed,
            .signedIn,
            .signedOut,
            .signInViewed,
            .signInTapped,
            .settingsOpened,
            .settingsAPIKeySaved,
            .settingsAPIKeyRemoved,
            .settingsHealthAppOpened,
            .healthMetricsViewed,
        ]
        for event in noPayloadEvents {
            #expect(event.properties.isEmpty, "Expected empty properties for \(event.name)")
        }
    }
}

// MARK: - FakeAnalyticsProvider Tests

@Suite("FakeAnalyticsProvider")
@MainActor
struct FakeAnalyticsProviderTests {

    @Test("track records events in order")
    func trackRecordsEvents() {
        let provider = FakeAnalyticsProvider()
        provider.track(event: .feedViewed)
        provider.track(event: .onboardingCompleted)
        #expect(provider.trackedEvents.count == 2)
        #expect(provider.trackedEvents[0].name == "Feed Viewed")
        #expect(provider.trackedEvents[1].name == "Onboarding Completed")
    }

    @Test("identify stores userId and properties")
    func identifyStoresData() {
        let provider = FakeAnalyticsProvider()
        provider.identify(userId: "user-123", properties: ["plan": "free"])
        #expect(provider.identifiedUserId == "user-123")
        #expect(provider.identifiedProperties["plan"] == "free")
    }
}

// MARK: - MixpanelAnalyticsService Tests

@Suite("MixpanelAnalyticsService")
@MainActor
struct MixpanelAnalyticsServiceTests {

    @Test("track does not crash for any event")
    func trackDoesNotCrash() {
        let service = MixpanelAnalyticsService()
        let events: [AnalyticsEvent] = [
            // Onboarding
            .onboardingCompleted,
            .healthKitPermissionGranted,
            .healthKitPermissionDenied,
            .healthKitPermissionsViewed,
            .healthKitPermissionRequested,
            // Authentication
            .signedIn,
            .signedOut,
            .signInViewed,
            .signInTapped,
            .signInFailed(reason: "test error"),
            // Feed
            .feedViewed,
            .feedLoadFailed,
            .feedFilterChanged(filter: "Sleep"),
            .patternCardTapped(pairId: "sleep_hrv"),
            // Pattern Detail
            .metricDetailViewed(metricId: "test"),
            .correlationViewed(metricId: "test"),
            .patternDetailChartTapped(pairId: "steps_rhr"),
            // Settings
            .settingsOpened,
            .settingsAPIKeySaved,
            .settingsAPIKeyRemoved,
            .settingsHealthAppOpened,
            // Health Metrics
            .healthMetricsViewed,
        ]
        for event in events {
            service.track(event: event)
        }
    }

    @Test("identify does not crash")
    func identifyDoesNotCrash() {
        let service = MixpanelAnalyticsService()
        service.identify(userId: "user-abc", properties: ["role": "tester"])
    }
}
