import Foundation

enum PatternDetailFormatter {
    static func effectSizeText(_ effectSize: Double?) -> String {
        guard let d = effectSize else { return "n/a" }
        let absD = abs(d)
        if absD >= 0.8 { return "large" }
        if absD >= 0.5 { return "medium" }
        if absD >= 0.2 { return "small" }
        return "negligible"
    }

    static func lagText(_ lagHours: Int) -> String {
        "\(lagHours)h"
    }

    static func correlationText(_ r: Double) -> String {
        "r=\(String(format: "%.2f", r))"
    }
}
