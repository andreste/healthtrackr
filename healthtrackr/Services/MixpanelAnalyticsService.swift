import os
import Foundation

#if canImport(Mixpanel)
import Mixpanel
#endif

@MainActor
final class MixpanelAnalyticsService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.healthtrackr", category: "Analytics")

    func track(event: AnalyticsEvent) {
        #if canImport(Mixpanel)
        Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
        #else
        logger.debug("[\(event.name)] \(event.properties.isEmpty ? "" : "\(event.properties)")")
        #endif
    }

    func identify(userId: String, properties: [String: String]) {
        #if canImport(Mixpanel)
        Mixpanel.mainInstance().identify(distinctId: userId)
        Mixpanel.mainInstance().people.set(properties: properties)
        #else
        logger.debug("[Identify] userId=\(userId, privacy: .private) properties=\(properties)")
        #endif
    }
}
