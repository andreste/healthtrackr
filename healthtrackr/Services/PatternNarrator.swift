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

    // MARK: - API Helpers

    private func buildSummary(for result: CorrelationResult) -> String {
        NarrationFormatter.buildSummary(for: result)
    }

    private func buildPrompt(summary: String) -> String {
        NarrationFormatter.buildPrompt(summary: summary)
    }

    private func parseResponse(data: Data, result: CorrelationResult) -> PatternNarration {
        NarrationFormatter.parseResponse(data: data, result: result)
    }

    private func fallbackNarration(for result: CorrelationResult) -> PatternNarration {
        NarrationFormatter.fallbackNarration(for: result)
    }
}
