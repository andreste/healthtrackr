import Foundation

nonisolated enum NarrationFormatter {
    static func buildSummary(for result: CorrelationResult) -> String {
        let pairLabel = humanReadablePair(result.pairId)
        let cohensDStr = result.effectSize.map { String(format: "d=%.2f", $0) } ?? "d=n/a"
        return "\(pairLabel): r=\(String(format: "%.2f", result.r)), " +
               "p=\(String(format: "%.4f", result.pValue)), " +
               "n=\(result.n), lag=\(result.lagHours)h, " +
               "cohen's \(cohensDStr)"
    }

    static func buildPrompt(summary: String) -> String {
        """
        You are a health data analyst writing for a general audience. \
        Given this correlation summary, write a short discovery for a health app.

        Rules:
        - Plain English, no medical claims or diagnoses
        - If lag is non-zero, explain what it means (e.g. "the effect shows up the next day")
        - Cite the sample size naturally (e.g. "based on 45 days of data")
        - One headline (max 10 words, no period) and one body paragraph (2-3 sentences)
        - Format: first line is the headline, remaining lines are the body

        Correlation: \(summary)
        """
    }

    static func humanReadablePair(_ pairId: String) -> String {
        switch pairId {
        case "sleep_hrv": return "Sleep duration and next-day HRV"
        case "steps_rhr": return "Steps and Resting Heart Rate"
        case "sleep_rhr": return "Sleep and Resting Heart Rate"
        case "activeEnergy_hrv": return "Active Energy and HRV"
        case "activeEnergy_rhr": return "Active Energy and Resting Heart Rate"
        case "exerciseTime_rhr": return "Exercise Time and Resting Heart Rate"
        case "exerciseTime_hrv": return "Exercise Time and HRV"
        case "steps_hrv": return "Steps and HRV"
        case "vo2Max_rhr": return "VO2 Max and Resting Heart Rate"
        case "distance_rhr": return "Walking Distance and Resting Heart Rate"
        case "sleep_walkingHR": return "Sleep and Walking Heart Rate"
        case "sleep_respiratoryRate": return "Sleep and Respiratory Rate"
        case "sleep_spo2": return "Sleep and Blood Oxygen Saturation"
        case "exerciseTime_walkingHR": return "Exercise Time and Walking Heart Rate"
        case "steps_walkingHR": return "Steps and Walking Heart Rate"
        case "bodyMass_rhr": return "Body Mass and Resting Heart Rate"
        case "bodyMass_vo2Max": return "Body Mass and VO2 Max"
        case "vo2Max_hrv": return "VO2 Max and HRV"
        case "vo2Max_walkingHR": return "VO2 Max and Walking Heart Rate"
        case "distance_hrv": return "Walking Distance and HRV"
        default: return pairId.replacingOccurrences(of: "_", with: " and ")
        }
    }

    static func parseAnthropicResponse(
        _ response: AnthropicMessageResponse,
        result: CorrelationResult
    ) -> PatternNarration {
        guard let text = response.text, !text.isEmpty else {
            return fallbackNarration(for: result)
        }

        let lines = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        guard let headline = lines.first else {
            return fallbackNarration(for: result)
        }

        let body = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)

        return PatternNarration(
            pairId: result.pairId,
            headline: headline,
            body: body.isEmpty ? fallbackBody(for: result) : body,
            cachedAt: Date()
        )
    }

    static func fallbackNarration(for result: CorrelationResult) -> PatternNarration {
        PatternNarration(
            pairId: result.pairId,
            headline: humanReadablePair(result.pairId),
            body: fallbackBody(for: result),
            cachedAt: Date()
        )
    }

    static func fallbackBody(for result: CorrelationResult) -> String {
        "Couldn't generate explanation right now. The pattern is still real " +
        "— r=\(String(format: "%.2f", result.r)), n=\(result.n), lag=\(result.lagHours)h."
    }
}
