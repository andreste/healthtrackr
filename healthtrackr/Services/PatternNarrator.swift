import Foundation

actor PatternNarrator {
    private let cache = CacheActor()
    private let session = URLSession.shared

    private var apiKey: String? {
        Bundle.main.infoDictionary?["ANTHROPIC_API_KEY"] as? String
    }

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"
    private static let maxBatchSize = 5

    // MARK: - Public

    func narrate(results: [CorrelationResult]) async -> [PatternNarration] {
        let confirmed = results.filter { $0.confidence == .high || $0.confidence == .medium }
        guard !confirmed.isEmpty else { return [] }

        let batch = Array(confirmed.prefix(Self.maxBatchSize))
        var narrations: [PatternNarration] = []

        for result in batch {
            // Check cache first
            if let cached = await cache.loadNarration(pairId: result.pairId, lagHours: result.lagHours) {
                narrations.append(cached)
                continue
            }

            let narration = await fetchNarration(for: result)
            narrations.append(narration)
            await cache.saveNarration(narration)
        }

        return narrations
    }

    // MARK: - API Call

    private func fetchNarration(for result: CorrelationResult) async -> PatternNarration {
        guard let key = apiKey, !key.isEmpty, key != "your-api-key-here" else {
            return fallbackNarration(for: result)
        }

        let summary = buildSummary(for: result)
        let prompt = buildPrompt(summary: summary)

        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 300,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return fallbackNarration(for: result)
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return fallbackNarration(for: result)
            }
            return parseResponse(data: data, result: result)
        } catch {
            return fallbackNarration(for: result)
        }
    }

    // MARK: - Summary (privacy-safe — no raw biometric values)

    private func buildSummary(for result: CorrelationResult) -> String {
        let pairLabel = humanReadablePair(result.pairId)
        let effectPct = String(format: "%.0f%%", result.effectSize * 100)
        return "\(pairLabel): r=\(String(format: "%.2f", result.r)), " +
               "p=\(String(format: "%.4f", result.pValue)), " +
               "n=\(result.n), lag=\(result.lagHours)h, " +
               "avg delta=\(effectPct)"
    }

    private func buildPrompt(summary: String) -> String {
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

    private func humanReadablePair(_ pairId: String) -> String {
        switch pairId {
        case "sleep_hrv": return "Sleep duration and next-day HRV"
        case "steps_rhr": return "Steps and Resting Heart Rate"
        default: return pairId.replacingOccurrences(of: "_", with: " and ")
        }
    }

    // MARK: - Response Parsing

    private func parseResponse(data: Data, result: CorrelationResult) -> PatternNarration {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let textBlock = content.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
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

    // MARK: - Fallback

    private func fallbackNarration(for result: CorrelationResult) -> PatternNarration {
        PatternNarration(
            pairId: result.pairId,
            headline: humanReadablePair(result.pairId),
            body: fallbackBody(for: result),
            cachedAt: Date()
        )
    }

    private func fallbackBody(for result: CorrelationResult) -> String {
        "Couldn't generate explanation right now. The pattern is still real " +
        "— r=\(String(format: "%.2f", result.r)), n=\(result.n), lag=\(result.lagHours)h."
    }
}
