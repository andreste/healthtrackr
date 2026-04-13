import Foundation

actor PatternNarrator {
    private let cache: CacheActor
    private let httpClient: any HTTPClientProviding

    init(httpClient: any HTTPClientProviding = HTTPClient(), cache: CacheActor = CacheActor()) {
        self.httpClient = httpClient
        self.cache = cache
    }

    static let keychainKey = "anthropic_api_key"

    private var apiKey: String? {
        // Info.plist (xcconfig) takes precedence; Keychain is the fallback for user-supplied keys
        if let key = AppConfig.anthropicAPIKey { return key }
        guard let data = KeychainHelper.read(key: Self.keychainKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static let apiURL = URL(string: "https://api.anthropic.com/v1/messages")!
    private var model: String { AppConfig.anthropicModel }
    private static let maxBatchSize = 5

    // MARK: - Public

    func narrate(results: [CorrelationResult]) async -> [PatternNarration] {
        let confirmed = results.filter { $0.confidence == .high || $0.confidence == .medium }
        guard !confirmed.isEmpty else { return [] }

        let batch = Array(confirmed.prefix(Self.maxBatchSize))
        var narrations: [PatternNarration] = []

        for result in batch {
            if await cache.isNarrationFresh(pairId: result.pairId, lagHours: result.lagHours),
               let cached = await cache.loadNarration(pairId: result.pairId, lagHours: result.lagHours) {
                narrations.append(cached)
                continue
            }

            let narration = await fetchNarration(for: result)
            narrations.append(narration)
            await cache.saveNarration(narration, lagHours: result.lagHours)
        }

        return narrations
    }

    // MARK: - API Call

    private func fetchNarration(for result: CorrelationResult) async -> PatternNarration {
        guard let key = apiKey, !key.isEmpty, key != "your-api-key-here" else {
            return NarrationFormatter.fallbackNarration(for: result)
        }

        let summary = NarrationFormatter.buildSummary(for: result)
        let prompt = NarrationFormatter.buildPrompt(summary: summary)

        let body = AnthropicMessageRequest(
            model: model,
            maxTokens: 300,
            messages: [.init(role: "user", content: prompt)]
        )

        var request = URLRequest(url: Self.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let response = try await httpClient.send(
                request: request,
                responseType: AnthropicMessageResponse.self
            )
            return NarrationFormatter.parseAnthropicResponse(response, result: result)
        } catch {
            return NarrationFormatter.fallbackNarration(for: result)
        }
    }
}
