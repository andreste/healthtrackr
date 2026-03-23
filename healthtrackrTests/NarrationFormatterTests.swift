import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeResult(
    pairId: String = "sleep_hrv",
    lagHours: Int = 36,
    r: Double = 0.71,
    pValue: Double = 0.003,
    n: Int = 52,
    effectSize: Double = 0.18,
    confidence: CorrelationResult.Confidence = .high
) -> CorrelationResult {
    CorrelationResult(
        pairId: pairId,
        lagHours: lagHours,
        r: r,
        pValue: pValue,
        n: n,
        effectSize: effectSize,
        confidence: confidence,
        computedAt: Date()
    )
}

private func makeAPIResponseData(headline: String, body: String) -> Data {
    let json: [String: Any] = [
        "content": [
            ["type": "text", "text": "\(headline)\n\(body)"]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: json)
}

// MARK: - humanReadablePair Tests

@Suite("NarrationFormatter.humanReadablePair")
struct HumanReadablePairFormatterTests {
    @Test("sleep_hrv maps correctly")
    func sleepHRV() {
        #expect(NarrationFormatter.humanReadablePair("sleep_hrv") == "Sleep duration and next-day HRV")
    }

    @Test("steps_rhr maps correctly")
    func stepsRHR() {
        #expect(NarrationFormatter.humanReadablePair("steps_rhr") == "Steps and Resting Heart Rate")
    }

    @Test("unknown pair replaces underscores with 'and'")
    func unknownPair() {
        #expect(NarrationFormatter.humanReadablePair("foo_bar") == "foo and bar")
    }
}

// MARK: - buildSummary Tests

@Suite("NarrationFormatter.buildSummary")
struct BuildSummaryTests {
    @Test("summary includes pair label, r, p, n, lag, and effect size")
    func summaryContainsAllFields() {
        let result = makeResult(r: 0.71, pValue: 0.003, n: 52, effectSize: 0.18)
        let summary = NarrationFormatter.buildSummary(for: result)

        #expect(summary.contains("Sleep duration and next-day HRV"))
        #expect(summary.contains("r=0.71"))
        #expect(summary.contains("p=0.0030"))
        #expect(summary.contains("n=52"))
        #expect(summary.contains("lag=36h"))
        #expect(summary.contains("avg delta=18%"))
    }

    @Test("summary formats negative r correctly")
    func negativeR() {
        let result = makeResult(r: -0.45)
        let summary = NarrationFormatter.buildSummary(for: result)
        #expect(summary.contains("r=-0.45"))
    }

    @Test("summary formats zero lag")
    func zeroLag() {
        let result = makeResult(lagHours: 0)
        let summary = NarrationFormatter.buildSummary(for: result)
        #expect(summary.contains("lag=0h"))
    }
}

// MARK: - buildPrompt Tests

@Suite("NarrationFormatter.buildPrompt")
struct BuildPromptTests {
    @Test("prompt includes summary and instructions")
    func promptStructure() {
        let prompt = NarrationFormatter.buildPrompt(summary: "test summary")
        #expect(prompt.contains("test summary"))
        #expect(prompt.contains("health data analyst"))
        #expect(prompt.contains("headline"))
        #expect(prompt.contains("body paragraph"))
    }

    @Test("prompt includes lag instruction")
    func promptLagInstruction() {
        let prompt = NarrationFormatter.buildPrompt(summary: "anything")
        #expect(prompt.contains("lag is non-zero"))
    }
}

// MARK: - parseResponse Tests

@Suite("NarrationFormatter.parseResponse")
struct ParseResponseTests {
    @Test("parses valid API response into headline and body")
    func validResponse() {
        let data = makeAPIResponseData(
            headline: "Sleep Boosts Your HRV",
            body: "More sleep leads to better HRV the next day."
        )
        let result = makeResult(pairId: "sleep_hrv")
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.pairId == "sleep_hrv")
        #expect(narration.headline == "Sleep Boosts Your HRV")
        #expect(narration.body == "More sleep leads to better HRV the next day.")
    }

    @Test("parses multi-line body into single paragraph")
    func multiLineBody() {
        let json: [String: Any] = [
            "content": [
                ["type": "text", "text": "Headline Here\nFirst sentence.\nSecond sentence."]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = makeResult()
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.headline == "Headline Here")
        #expect(narration.body == "First sentence. Second sentence.")
    }

    @Test("falls back on invalid JSON")
    func invalidJSON() {
        let data = "not json".data(using: .utf8)!
        let result = makeResult(pairId: "sleep_hrv")
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.headline == "Sleep duration and next-day HRV")
        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back on missing content array")
    func missingContent() {
        let json: [String: Any] = ["id": "msg_123"]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = makeResult()
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back on empty text")
    func emptyText() {
        let json: [String: Any] = [
            "content": [
                ["type": "text", "text": ""]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = makeResult()
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back when body is empty but headline exists")
    func headlineOnlyResponse() {
        let json: [String: Any] = [
            "content": [
                ["type": "text", "text": "Just A Headline"]
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = makeResult()
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.headline == "Just A Headline")
        #expect(narration.body.contains("r=0.71"))
    }

    @Test("ignores non-text content blocks")
    func ignoresNonTextBlocks() {
        let json: [String: Any] = [
            "content": [
                ["type": "image", "source": "data"],
                ["type": "text", "text": "Real Headline\nReal body text."],
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let result = makeResult()
        let narration = NarrationFormatter.parseResponse(data: data, result: result)

        #expect(narration.headline == "Real Headline")
        #expect(narration.body == "Real body text.")
    }
}

// MARK: - Fallback Tests

@Suite("NarrationFormatter.fallback")
struct FallbackTests {
    @Test("fallbackNarration uses humanReadablePair as headline")
    func fallbackHeadline() {
        let result = makeResult(pairId: "sleep_hrv")
        let narration = NarrationFormatter.fallbackNarration(for: result)
        #expect(narration.headline == "Sleep duration and next-day HRV")
    }

    @Test("fallbackNarration includes stats in body")
    func fallbackBodyStats() {
        let result = makeResult(lagHours: 36, r: 0.71, n: 52)
        let narration = NarrationFormatter.fallbackNarration(for: result)
        #expect(narration.body.contains("r=0.71"))
        #expect(narration.body.contains("n=52"))
        #expect(narration.body.contains("lag=36h"))
    }

    @Test("fallbackBody formats negative r")
    func fallbackNegativeR() {
        let result = makeResult(r: -0.45)
        let body = NarrationFormatter.fallbackBody(for: result)
        #expect(body.contains("r=-0.45"))
    }

    @Test("fallbackNarration preserves pairId")
    func fallbackPreservesPairId() {
        let result = makeResult(pairId: "steps_rhr")
        let narration = NarrationFormatter.fallbackNarration(for: result)
        #expect(narration.pairId == "steps_rhr")
    }
}

// MARK: - PatternNarrator Integration Tests

@Suite("PatternNarrator")
struct PatternNarratorTests {
    @Test("narrate returns empty for empty results")
    func emptyResults() async {
        let narrator = PatternNarrator()
        let narrations = await narrator.narrate(results: [])
        #expect(narrations.isEmpty)
    }

    @Test("narrate filters out hidden and emerging results")
    func filtersLowConfidence() async {
        let narrator = PatternNarrator()
        let results = [
            makeResult(confidence: .hidden),
            makeResult(confidence: .emerging),
        ]
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.isEmpty)
    }

    @Test("narrate processes high confidence results")
    func processesHighConfidence() async {
        let narrator = PatternNarrator()
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "sleep_hrv")
    }

    @Test("narrate processes medium confidence results")
    func processesMediumConfidence() async {
        let narrator = PatternNarrator()
        let results = [makeResult(pairId: "steps_rhr", confidence: .medium)]
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.count == 1)
        #expect(narrations.first?.pairId == "steps_rhr")
    }

    @Test("narrate returns narration with matching pairId")
    func narrationMatchesPairId() async {
        let narrator = PatternNarrator()
        let results = [makeResult(pairId: "sleep_hrv", confidence: .high)]
        let narrations = await narrator.narrate(results: results)

        #expect(narrations.first?.pairId == "sleep_hrv")
        #expect(narrations.first?.headline.isEmpty == false)
        #expect(narrations.first?.body.isEmpty == false)
    }

    @Test("narrate limits batch to maxBatchSize")
    func limitsBatchSize() async {
        let narrator = PatternNarrator()
        let results = (0..<10).map { i in
            makeResult(pairId: "pair_\(i)", lagHours: i, confidence: .high)
        }
        let narrations = await narrator.narrate(results: results)
        #expect(narrations.count <= 5)
    }
}
