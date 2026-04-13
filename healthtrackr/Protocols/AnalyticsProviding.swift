import Foundation

@MainActor
protocol AnalyticsProviding {
    func track(event: AnalyticsEvent)
    func identify(userId: String, properties: [String: String])
}

extension MixpanelAnalyticsService: AnalyticsProviding {}
