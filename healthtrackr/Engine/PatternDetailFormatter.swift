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
        "\(lagHours)h"
    }

    static func correlationText(_ r: Double) -> String {
        "r=\(String(format: "%.2f", r))"
    }
}
