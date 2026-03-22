# Product Requirements Document — healthtrackr

**Version:** 1.0
**Status:** Approved
**Date:** 2026-03-22
**Platform:** iOS (SwiftUI)
**Source:** Derived from /office-hours design session + adversarial spec review (quality score: 8/10)

---

## 1. Overview

healthtrackr is an iOS app that reads data from Apple HealthKit and surfaces non-obvious cross-metric patterns to the user. It is not a dashboard or a better visualization of existing data.

**Core insight:** Apple Health is a data warehouse. healthtrackr is the analyst sitting on top of it. The value is connective tissue — "your HRV drops 36 hours after a short-sleep night, not the next morning" — not prettier charts.

---

## 2. Problem Statement

Apple Health collects rich biometric data but presents it in siloed, per-metric views. Users have no way to discover relationships between metrics, especially delayed ones (e.g. how Tuesday's workout affects Thursday's recovery). Existing third-party apps either go deep on one metric (AutoSleep, Oura) or require new hardware. No app treats HealthKit as a dataset to reason across.

healthtrackr solves this by running cross-metric statistical analysis on-device and translating confirmed patterns into plain-English discoveries.

---

## 3. Goals

- Surface at least 1 statistically significant pattern for any user with 90 days of HealthKit data
- Produce pattern narratives that pass the "would I text this to a friend?" test — readable, not clinical
- Guarantee raw HealthKit data never leaves the device
- Require zero manual logging from the user

---

## 4. Non-Goals (V1)

- No health coaching or recommendations
- No manual data entry or journaling
- No push notifications (V1 is pull-only; V1.1 consideration)
- No cross-platform support (iOS only)
- No social or sharing features
- No sparklines or advanced visualizations (deferred to V1.1)
- No metric pairs beyond Sleep+HRV and Steps+Resting HR (deferred to V1.1)

---

## 5. Target User

Personal-use iOS user with an Apple Watch or iPhone that has accumulated 30–90 days of health data in Apple Health. No special hardware required beyond what they already have.

---

## 6. V1 Scope

V1 is limited to two metric pairs:

| Pair | Metrics | Why |
|------|---------|-----|
| Sleep + HRV | Sleep duration (HKCategoryTypeIdentifierSleepAnalysis) + HRV (HKQuantityTypeIdentifierHeartRateVariabilitySDNN) | High-signal relationship; well-documented in literature; universally available via Apple Watch |
| Steps + Resting HR | Step count (HKQuantityTypeIdentifierStepCount) + Resting HR (HKQuantityTypeIdentifierRestingHeartRate) | Easy to observe, consistent data, good for building user confidence in the app |

Additional pairs (Sleep+ExerciseTiming, HRV+WorkoutIntensity) are deferred to V1.1.

---

## 7. Architecture

### 7.1 Approach: Hybrid Stats + AI Narration

Three approaches were evaluated:

| Approach | Summary | Chosen? |
|----------|---------|---------|
| A: Local stats only | On-device Spearman correlation, mechanical labels | No — explanations lack readability |
| B: AI only | Send raw data to Claude API for pattern detection | No — raw biometric data leaves device |
| **C: Hybrid (chosen)** | On-device stats validate patterns; only summaries sent to AI for narration | **Yes** |

**Why Approach C:** The stats layer is the safety net. AI narrates only confirmed signals — it never invents them. Claude API input is a structured summary (e.g. `"Sleep duration and next-day HRV: r=0.71, n=14, lag=36h, avg delta=-18%"`), not raw biometric data. Privacy is preserved, output is trustworthy.

### 7.2 Components

#### HealthKitManager
- Async data fetcher for 4 HKQuantityType metrics: HRV, sleep, step count, resting HR
- Fetches up to 90-day windows; degrades gracefully to 30+ days if less data available
- Handles partial permissions — each metric independently authorized; missing metrics flagged in UI, not fatal
- If authorization denied entirely: show "Connect Apple Health" re-prompt screen

#### CorrelationEngine
- On-device Spearman rank correlation across the 2 V1 metric pairs
- **Lag offsets tested:** 0h, 12h, 24h, 36h, 48h (covers circadian and autonomic recovery cycles)
- **Lag definition:** Lag N = Day 0 metric A correlated with Day N metric B. Example: Day 0 sleep duration vs. Day 1 morning HRV = 24h lag
- **Time window alignment:** Daily-resolution metrics (sleep, resting HR, steps) aggregated into 24h day buckets. HRV samples aggregated into morning windows (5–9am) to match post-sleep recovery signal
- **Significance thresholds:**
  - r ≥ 0.5, p < 0.05, n ≥ 30 → shown as confirmed pattern
  - n = 20–29 → flagged "Emerging" (shown with lower confidence)
  - n < 20 → hidden entirely
- **Confidence levels displayed to user:**
  - High: p < 0.01
  - Medium: p < 0.05
  - Emerging: n < 30
- **Caching:** Results stored in UserDefaults with timestamp. Re-run only if cache is >24h stale. Fresh run triggered as background Swift Task on app open; UI shows cached results immediately
- **Implementation:** Use Accelerate framework for ranked correlation math (not a custom implementation)
- **Compute budget:** 2 pairs × 5 lags = 10 correlation runs (sub-second on iPhone 12+)

#### PatternNarrator
- Sends CorrelationResult summaries to Claude API (claude-haiku model for cost efficiency)
- **Input format:** Structured text summary only — never raw biometric data. Example input: `"Sleep duration and next-day HRV: r=0.71, n=14, lag=36h, avg delta=-18%"`
- **Prompt rules:** Plain English, no medical claims, explain lag if non-zero, cite sample size
- **Batch size:** Max 5 confirmed patterns per API call (~500 tokens input)
- **API key:** Hardcoded constant for V1 (personal-use prototype). Keychain / server-side proxy deferred to V1.1 before any public distribution
- Results cached alongside CorrelationResult in UserDefaults

#### DiscoveryFeed UI
- SwiftUI card feed; each PatternCard shows:
  - Metric pair badge (e.g. "Sleep + HRV")
  - Pattern headline
  - Body (AI-generated narrative)
  - Confidence level chip (High / Medium / Emerging)
  - "See full pattern" CTA → navigates to PatternDetail
- **Loading state:** Per-pair "Analyzing..." placeholder while correlation runs in background
- **Empty state:** "No strong patterns yet — check back as more data accumulates"
- **Cold-start UX:** Data readiness checklist shown on first launch. Per-pair: if <30 days of data, show "Need more data — check back in X days" with estimated date

#### PatternDetail UI
- Scatter plot (Apple Charts framework): metric A on X-axis, metric B on Y-axis, at best-fit lag offset
- Stat row: correlation coefficient (r), lag offset, effect size (avg delta %)
- AI narration box: plain-English explanation from PatternNarrator
- "How we found this" transparency box: deferred to V1.1

---

## 8. Screens

Three screens (wireframe at `/tmp/gstack-sketch.png`):

| Screen | Description |
|--------|-------------|
| First Launch | Data readiness checklist — shows which metrics have enough history; "Start finding patterns" CTA |
| Discovery Feed | Card feed of confirmed patterns with confidence levels |
| Pattern Detail | Scatter plot + stat row + AI narration for a single metric pair |

---

## 9. Data & Privacy

- **Raw HealthKit data never leaves the device** — verifiable via network inspector
- Only pattern summaries (statistical results) are sent to Claude API
- Pattern summaries sent to Claude API are subject to Anthropic's data usage policy; disclosure required in app Settings screen
- Apple Health review guidelines: no medical claims in UI copy or App Store description

---

## 10. Performance Requirements

| Scenario | Target |
|----------|--------|
| App open → cached discoveries visible | < 1 second |
| Fresh correlation run (background) | 2–5 seconds on iPhone 12+ |
| Claude API narration (batch) | < 3 seconds for ≤5 patterns |

---

## 11. Success Criteria

- App surfaces at least 1 statistically significant pattern for a user with 90 days of HealthKit data
- Pattern narrative passes the "would I text this to a friend?" test — readable, not clinical
- Raw HealthKit data confirmed never leaves device (verifiable in Charles / network inspector)
- Cached results visible in under 1 second on app open

---

## 12. Open Questions

| Question | Resolution |
|----------|------------|
| Notifications? | V1 is pull-only. Push notifications for new patterns deferred to V1.1 |
| Anthropic data retention? | Add disclosure in Settings screen pointing to Anthropic's privacy policy |
| No patterns found state? | Show "Analyzing..." on first run; after completion, show "No strong patterns yet — check back as more data accumulates" |
| Secret management? | Hardcoded API key for V1 prototype. Keychain/proxy required before any public release |

---

## 13. Implementation Plan

| Step | Task |
|------|------|
| 1 | Set up HealthKit entitlements + HKHealthStore authorization flow in Xcode |
| 2 | Build HealthKitManager with async fetchers for 4 V1 metric types; handle partial permissions |
| 3 | Implement CorrelationEngine: Spearman via Accelerate, lag offsets, time window alignment, caching |
| 4 | Wire up Claude Haiku API with pattern narration prompt; batch results |
| 5 | Build DiscoveryFeed SwiftUI view with PatternCard, loading, and empty states |
| 6 | Build PatternDetail view with Apple Charts scatter plot and stat row |
| 7 | Test on real device with own HealthKit data; verify no data leaves device |

---

## 14. V1.1 Backlog

- Additional metric pairs: Sleep+ExerciseTiming, HRV+WorkoutIntensity, Active Energy+RestingHR
- Sparklines on PatternCard
- "How we found this" transparency box on PatternDetail
- Push notifications for new pattern discoveries
- API key secret management (Keychain or server-side proxy)
- Pattern history / trend over time view

---

## 15. References

- Design doc: `~/.gstack/projects/andreste-healthtrackr/andrestrevino-main-design-20260322-123040.md`
- Wireframe: `/tmp/gstack-sketch-1774196781.html` / `/tmp/gstack-sketch.png`
- Apple HealthKit docs: developer.apple.com/documentation/healthkit
- Apple Charts framework: developer.apple.com/documentation/charts
- Accelerate framework (vDSP): developer.apple.com/documentation/accelerate
