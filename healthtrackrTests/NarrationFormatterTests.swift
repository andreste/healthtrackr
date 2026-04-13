import Foundation
import Testing
@testable import healthtrackr

// MARK: - Helpers

private func makeAnthropicResponse(text: String?) -> AnthropicMessageResponse {
    if let text {
        return AnthropicMessageResponse(
            content: [AnthropicMessageResponse.ContentBlock(type: "text", text: text)]
        )
    }
    return AnthropicMessageResponse(content: [])
}

private func makeAnthropicResponse(blocks: [AnthropicMessageResponse.ContentBlock]) -> AnthropicMessageResponse {
    AnthropicMessageResponse(content: blocks)
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

    @Test("all v1Pairs have explicit AI-prompt labels (no fallback to underscore replacement)")
    func allV1PairsHaveExplicitLabels() {
        for pair in CorrelationEngine.v1Pairs {
            let label = NarrationFormatter.humanReadablePair(pair.id)
            // The fallback replaces "_" with " and " — if it fires the label contains the raw id segment
            let fallback = pair.id.replacingOccurrences(of: "_", with: " and ")
            #expect(label != fallback, "pair \(pair.id) is using the generic fallback label in NarrationFormatter")
        }
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
        #expect(summary.contains("cohen's d=0.18"))
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

// MARK: - parseAnthropicResponse Tests

@Suite("NarrationFormatter.parseAnthropicResponse")
struct ParseAnthropicResponseTests {
    @Test("parses valid response into headline and body")
    func validResponse() {
        let response = makeAnthropicResponse(text: "Sleep Boosts Your HRV\nMore sleep leads to better HRV the next day.")
        let result = makeResult(pairId: "sleep_hrv")
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.pairId == "sleep_hrv")
        #expect(narration.headline == "Sleep Boosts Your HRV")
        #expect(narration.body == "More sleep leads to better HRV the next day.")
    }

    @Test("parses multi-line body into single paragraph")
    func multiLineBody() {
        let response = makeAnthropicResponse(text: "Headline Here\nFirst sentence.\nSecond sentence.")
        let result = makeResult()
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.headline == "Headline Here")
        #expect(narration.body == "First sentence. Second sentence.")
    }

    @Test("falls back on empty content blocks")
    func emptyContentBlocks() {
        let response = makeAnthropicResponse(text: nil)
        let result = makeResult(pairId: "sleep_hrv")
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.headline == "Sleep duration and next-day HRV")
        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back on nil text in content block")
    func nilText() {
        let response = makeAnthropicResponse(
            blocks: [AnthropicMessageResponse.ContentBlock(type: "text", text: nil)]
        )
        let result = makeResult()
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back on empty text")
    func emptyText() {
        let response = makeAnthropicResponse(text: "")
        let result = makeResult()
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.body.contains("Couldn't generate explanation"))
    }

    @Test("falls back when body is empty but headline exists")
    func headlineOnlyResponse() {
        let response = makeAnthropicResponse(text: "Just A Headline")
        let result = makeResult()
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

        #expect(narration.headline == "Just A Headline")
        #expect(narration.body.contains("r=0.71"))
    }

    @Test("ignores non-text content blocks")
    func ignoresNonTextBlocks() {
        let response = makeAnthropicResponse(blocks: [
            AnthropicMessageResponse.ContentBlock(type: "image", text: nil),
            AnthropicMessageResponse.ContentBlock(type: "text", text: "Real Headline\nReal body text."),
        ])
        let result = makeResult()
        let narration = NarrationFormatter.parseAnthropicResponse(response, result: result)

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

