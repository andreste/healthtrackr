import Foundation

enum PatternDetailFormatter {
    static func effectSizeText(_ effectSize: Double?) -> String {
        guard let d = effectSize else {
            return String(localized: "effect.size.not_available", bundle: Bundle.localization)
        }
        let absD = abs(d)
        if absD >= 0.8 { return String(localized: "effect.size.large", bundle: Bundle.localization) }
        if absD >= 0.5 { return String(localized: "effect.size.medium", bundle: Bundle.localization) }
        if absD >= 0.2 { return String(localized: "effect.size.small", bundle: Bundle.localization) }
        return String(localized: "effect.size.negligible", bundle: Bundle.localization)
    }

    static func lagText(_ lagHours: Int) -> String {
        switch lagHours {
        case 0, 12:
            return String(localized: "lag.same_day", bundle: Bundle.localization)
        case 24, 36:
            return String(localized: "lag.next_day", bundle: Bundle.localization)
        case 48:
            return String(localized: "lag.two_days", bundle: Bundle.localization)
        default:
            let days = lagHours / 24
            return String(
                format: String(localized: "lag.days_later", bundle: Bundle.localization),
                days
            )
        }
    }

    static func correlationText(_ r: Double) -> String {
        let absR = abs(r)
        if absR >= 0.7 { return String(localized: "correlation.very_strong", bundle: Bundle.localization) }
        if absR >= 0.5 { return String(localized: "correlation.strong", bundle: Bundle.localization) }
        if absR >= 0.3 { return String(localized: "correlation.moderate", bundle: Bundle.localization) }
        if absR >= 0.1 { return String(localized: "correlation.weak", bundle: Bundle.localization) }
        return String(localized: "correlation.very_weak", bundle: Bundle.localization)
    }
}
