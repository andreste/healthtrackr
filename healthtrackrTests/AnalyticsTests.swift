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

    @Test("feedViewed has correct name")
    func feedViewedName() {
        #expect(AnalyticsEvent.feedViewed.name == "Feed Viewed")
    }

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

    @Test("events without payload have empty properties")
    func noPayloadEventsHaveEmptyProperties() {
        #expect(AnalyticsEvent.onboardingCompleted.properties.isEmpty)
        #expect(AnalyticsEvent.feedViewed.properties.isEmpty)
        #expect(AnalyticsEvent.signedIn.properties.isEmpty)
        #expect(AnalyticsEvent.signedOut.properties.isEmpty)
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
            .onboardingCompleted,
            .healthKitPermissionGranted,
            .healthKitPermissionDenied,
            .feedViewed,
            .metricDetailViewed(metricId: "test"),
            .correlationViewed(metricId: "test"),
            .settingsOpened,
            .signedIn,
            .signedOut
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
