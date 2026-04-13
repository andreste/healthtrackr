import Foundation

enum AppConfig {
    static var anthropicAPIKey: String? {
        value(for: "ANTHROPIC_API_KEY")
    }

    static var anthropicModel: String {
        value(for: "ANTHROPIC_MODEL") ?? "claude-haiku-4-5-20251001"
    }

    static var mixpanelToken: String? {
        value(for: "MIXPANEL_TOKEN")
    }

    private static func value(for key: String) -> String? {
        guard let raw = Bundle.main.infoDictionary?[key] as? String,
              !raw.isEmpty,
              !raw.hasPrefix("$(") else { return nil }
        return raw
    }
}
