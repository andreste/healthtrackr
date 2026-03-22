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

#### AuthManager
- Wraps `ASAuthorizationAppleIDProvider` and `ASAuthorizationController`
- On first launch: presents Sign in with Apple sheet; stores `userIdentifier` + `identityToken` in Keychain on success
- On subsequent launches: reads Keychain; calls `getCredentialState(forUserID:)` async; routes to Sign In or Discovery Feed accordingly
- Exposes `@Published var isAuthenticated: Bool` to drive root navigation in SwiftUI
- Sign out: clears Keychain entry; does NOT delete cached HealthKit data or correlation results

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
- **Navigation:** No tab bar in V1. Nav stack only. Gear icon (top-right of nav bar) opens inline Settings sheet (Anthropic disclosure).
- **Filter chips:** 3 chips — "All" (default), "Sleep + HRV", "Steps + HR". Styled per `DESIGN.md §Metric Chips`. Active chip: `borderPrimary` + `surfaceSecondary` fill.
- SwiftUI card feed; each PatternCard shows (see `DESIGN.md §Discovery Card` for token specs):
  - Metric pair badge (e.g. "Sleep + HRV") — `cardBadge` style: uppercase, tracked, `textSecondary` color, `borderSubtle` border
  - Pattern headline — Fraunces variable serif, 17pt, `textPrimary`. Written to surprise, not describe (see §12.5)
  - Body — Instrument Sans, 14pt, `textSecondary`. 3 lines max, then truncated
  - Confidence level chip (High / Medium / Emerging) — `DESIGN.md §Confidence Bar` tokens: High=`semanticSuccess`, Medium=`semanticWarning`, Emerging=`textTertiary`
  - "See full pattern" CTA — underlined, `accentPrimary` color, Instrument Sans 13pt semibold
- **Loading state:** Per-pair "Analyzing..." placeholder — dashed border (`borderSubtle`), 3-line skeleton shimmer. No spinner.
- **Empty state:** Centered text block — "No strong patterns yet." (Fraunces, 17pt) + "Check back as more data accumulates." (Instrument Sans, 14pt, `textSecondary`)
- **Cold-start UX:** Data readiness checklist shown on first launch. Per-pair: if <30 days, show "Need more data — check back in {X} days" with estimated date

#### PatternDetail UI
- Scatter plot (Apple Charts framework): metric A on X-axis, metric B on Y-axis, at best-fit lag offset. Dot color: `accentPrimary`. Axis labels: Geist Mono, 11pt, `textSecondary`. No grid lines — Apple Charts default grid is too visually heavy for the editorial aesthetic. **Tap interaction:** `chartOverlay` modifier shows custom callout on dot tap — date (Instrument Sans, 12pt, `textSecondary`), metric A value and metric B value (Geist Mono, 14pt, `textPrimary`), in a `surfaceSecondary` rounded card (`radiusSM`). Dismiss on tap-outside.
- Stat row (see `DESIGN.md §Stat Row`): 3 cells — effect size (−18%), lag (36h), correlation (r=0.71). Values in Geist Mono 22pt bold; labels in Instrument Sans 10pt `textSecondary`.
- AI narration box (see `DESIGN.md §Narration Box`): `surfaceSecondary` background, Instrument Sans 14pt, `textPrimary`. "What this means" label in uppercase tracked `textSecondary` 11pt.
- "How we found this" transparency box: deferred to V1.1. In V1, omit the section entirely — do not show a disabled/grayed-out placeholder.

---

## 8. Screens

Four screens (wireframe at `/tmp/gstack-sketch.png`):

| Screen | Description |
|--------|-------------|
| Sign In | Sign in with Apple — required on first launch; session persists across app opens |
| First Launch | Data readiness checklist — shows which metrics have enough history; "Start finding patterns" CTA |
| Discovery Feed | Card feed of confirmed patterns with confidence levels |
| Pattern Detail | Scatter plot + stat row + AI narration for a single metric pair |

### App Flow

```
Sign In (first launch only)
    ↓ (Sign in with Apple succeeds)
First Launch / Data Readiness
    ↓ ("Start finding patterns" CTA)
Discovery Feed
    ↓ (tap "See full pattern")
Pattern Detail
    ↑ (back)
Discovery Feed
```

Session persists — user is never shown Sign In again unless they explicitly sign out from Settings.

### 8.0 Sign In Screen

**Purpose:** Establish identity before HealthKit access. Enables future iCloud sync of discovered patterns.

**Layout (full-screen, centered):**
1. App name "healthtrackr" — Fraunces variable serif, 28pt, `textPrimary` (same treatment as hero tagline)
2. Tagline — "Find patterns in your health data you wouldn't notice on your own." Instrument Sans, 16pt, `textSecondary`, max 2 lines, centered
3. Privacy reassurance — "Your health data never leaves your device." Instrument Sans, 13pt, `textTertiary`, centered. Positioned between tagline and CTA to preempt the trust question.
4. **Sign in with Apple button** — uses `ASAuthorizationAppleIDButton` (system-provided, `.black` style in light mode, `.white` style in dark mode). Full-width with 16pt horizontal insets. Apple requires this exact button — do not customize.
5. Privacy footnote — "By continuing, you agree to our [Privacy Policy]." Instrument Sans, 11pt, `textTertiary`, centered, below button.

**Background:** `surfacePrimary` (warm off-white in light, deep warm gray in dark). No imagery, no gradient — editorial blank canvas.

**What this screen does NOT have:** social proof, feature lists, screenshots of the app. The tagline does all the work. First screen should feel like opening a notebook, not a product landing page.

**Implementation notes:**
- Use `AuthenticationServices` framework: `ASAuthorizationAppleIDProvider` + `ASAuthorizationController`
- Request scopes: `.fullName` and `.email` (required once; Apple only provides these on first sign-in)
- Store `userIdentifier` in Keychain for session persistence — not UserDefaults
- On subsequent launches: check Keychain for stored `userIdentifier`; if present, skip Sign In and go directly to Discovery Feed (or First Launch if data readiness hasn't been completed)
- Credential state check on every launch: `ASAuthorizationAppleIDProvider().getCredentialState(forUserID:)` — handle `.revoked` and `.notFound` by returning to Sign In screen
- Sign out: available in Settings sheet (gear icon in DiscoveryFeed nav bar); clears Keychain entry

### 8.1 Information Hierarchy

**Sign In**
1. App name (anchors identity — this is healthtrackr, not a generic auth screen)
2. Tagline (establishes value before asking for anything)
3. Privacy reassurance (pre-empts the data concern before the button)
4. Sign in with Apple button (single action — no alternatives, no skip)
5. Privacy footnote (legal, below the fold of attention)

**First Launch**
1. Product name + tagline (establishes intent, earns trust before asking for permissions)
2. Data readiness checklist (per-metric status rows: metric name + days available / "Not enough yet")
3. Primary CTA: "Start finding patterns" (full-width, prominent — only available when ≥1 pair has 30+ days)
4. Privacy note (small, below CTA: "Analysis runs on your device. Only pattern summaries are sent to AI.")

**Discovery Feed**
1. Featured PatternCard (top card, visually heavier — highest-confidence finding or most recent)
2. Secondary PatternCards (standard weight, scrollable)
3. "Analyzing..." placeholder cards (dashed border, lower visual weight — show while correlation runs)
4. Nav bar title "Discoveries" + last-updated timestamp (contextual, not primary)

**Pattern Detail**
1. Pattern headline + metric pair label (first thing user reads — names the discovery)
2. Scatter plot (Apple Charts; visual evidence that earns trust in the claim)
3. Stat row (r-value, lag, effect size — numbers that validate the chart)
4. AI narration box (plain-English explanation — what the stats mean for this user)
5. Back navigation to Discovery Feed

**Visual hierarchy rule:** Fraunces (display serif) is reserved for discovery headlines only — never labels, badges, or nav. This creates a semantic signal: "Fraunces = something worth knowing."

### 8.2 Interaction State Coverage

Every state below describes what the **user sees**, not backend behavior.

#### Sign In

| State | Trigger | What user sees |
|-------|---------|----------------|
| Default | First launch (no session in Keychain) | Full-screen Sign In layout as described in §8.0 |
| Loading | Tapped Sign in with Apple, sheet presented | System Apple ID sheet (modal, handled by OS — no custom loading state needed) |
| Success | Sign in completes | Transition to First Launch screen (push navigation, `durationMedium` 280ms ease-out) |
| Error | Sign in fails or user cancels | Return to Sign In screen; no error message shown for user cancellation; network/system errors show system alert (ASAuthorizationError) |
| Returning user | Keychain has valid session | Sign In screen never shown; app opens directly to Discovery Feed |
| Revoked | Apple ID credential revoked | Return to Sign In screen on next launch; no destructive data action — local HealthKit data and cached patterns remain |

#### DiscoveryFeed

| State | Trigger | What user sees |
|-------|---------|----------------|
| First launch / no cache | App open, no prior run | All PatternCard slots show dashed-border "Analyzing..." placeholder with per-pair progress label (e.g. "Sleep + HRV: analyzing...") |
| Cached results | App open, cache < 24h stale | Cards appear immediately (< 1 second); background re-run fires silently; no loading indicator unless cache is stale |
| Partial results | One pair done, one still running | Completed pair card renders; remaining pair shows "Analyzing..." placeholder |
| Confirmed patterns | Correlation complete, ≥1 pattern passes threshold | PatternCards in full state: badge, headline, body, confidence chip, "See full pattern" CTA |
| Empty (no patterns) | Correlation complete, no pair passes threshold | Single centered card with: "No strong patterns yet." + "Check back as more data accumulates — patterns need at least 30 days." No CTA. |
| HealthKit denied | User denied all HealthKit permissions | Full-screen "Connect Apple Health" prompt with re-authorization CTA; no feed shown |
| HealthKit partial | Some metrics authorized, some denied | Available-pair cards shown; denied-metric pairs show "Missing data" badge in place of confidence chip |

#### PatternDetail

| State | Trigger | What user sees |
|-------|---------|----------------|
| Loading narrative | Tapped "See full pattern", AI call in-flight | Chart and stat row render immediately from cached CorrelationResult; narration box shows skeleton shimmer (3 lines, Instrument Sans placeholder) |
| Loaded | AI narration received | Full screen: chart + stat row + narration box + "How we found this" row (deferred V1.1, shown grayed-out) |
| API error | Claude API call fails | Narration box shows: "Couldn't generate explanation right now." + "The pattern is still real — r={value}, n={n}, lag={lag}h." Stat row always visible. |
| Cache hit | Narration was previously fetched | Narration renders immediately alongside chart; no loading state |

#### First Launch / Data Readiness

| State | Trigger | What user sees |
|-------|---------|----------------|
| Sufficient data (both pairs ≥30 days) | First open, adequate history | Checklist rows show "✓ 90 days" (or actual count); CTA is active ("Start finding patterns") |
| Partial data | One pair has 30+ days, one doesn't | Sufficient pair row: "✓ {N} days"; insufficient pair row: "Need more data — check back in {X} days"; CTA is still active for the ready pair |
| Insufficient data (all pairs < 30 days) | New Apple Watch / Health user | All rows show "Need more data"; CTA is disabled and grayed out; estimated date shown for soonest-ready pair |
| HealthKit not authorized | First launch, permissions not yet granted | Prompt screen shown first; after authorization, redirect to data readiness checklist |

#### Edge Cases
- **45 days of data** (between the 30-day minimum and 90-day ideal): app shows "Emerging" confidence badge if n=20–29, "Confirmed" if n≥30 correlations exist in the window. No special UI state needed beyond the existing confidence chip.
- **Long metric names / localized strings**: all card text truncates at 2 lines with `lineLimit(2)` + ellipsis; no layout breaks.
- **Zero HRV samples in window**: Sleep+HRV pair shows "Missing data" badge (same as partial HealthKit auth) with subtext "No HRV data in the last 90 days. Check that Apple Watch is worn during sleep."

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
| Chart tap behavior? | **Resolved:** Custom callout overlay on dot tap — shows date + metric A value + metric B value, styled to DESIGN.md tokens (surfaceSecondary background, Geist Mono values). Use Apple Charts `chartOverlay` modifier. |
| Filter chips? | **Resolved:** Simplified to 3 chips in V1 — "All", "Sleep + HRV", "Steps + HR". Matches actual pairs. Expand to per-metric chips in V1.1. |
| Tab bar? | **Resolved:** No tab bar in V1. Simple nav stack: DiscoveryFeed → PatternDetail (back nav). Settings accessible via nav bar icon (gear icon, top right of DiscoveryFeed). Add tab bar in V1.1 when Metrics and History screens exist. |

---

## 12.5 User Journey & Emotional Arc

### The Critical Moments

| Step | User action | What user feels | How the design supports it |
|------|-------------|-----------------|---------------------------|
| 1 | Sees Sign In screen for first time | Skeptical — "another health app that wants my account" | Tagline names the mechanic before asking for anything; privacy reassurance appears before the button |
| 2 | Signs in with Apple | Mild friction — but familiar system sheet | Apple's system sheet is trusted UI; app doesn't handle credentials at all |
| 3 | HealthKit permission prompt | Anxious — "what will it do with my data?" | Privacy note appears *before* the system permission dialog: "Analysis runs on your device. Only pattern summaries are sent to AI." |
| 3 | Waiting for analysis | Impatient | "Analyzing..." placeholders show per-pair progress labels — user knows exactly what's happening and for which pairs |
| 4 | First PatternCard appears | Curious → surprised | Headline is written to surprise ("your HRV drops 36 hours after..."), not to state the obvious ("HRV correlates with sleep") |
| 5 | Taps "See full pattern" | Skeptical — "is this real?" | Chart renders first; stat row (r-value, p-value, n) renders before narrative. Math earns the explanation, not the other way around. |
| 6 | Reads AI narration | Converted or not | Narration passes the "would I text this?" test: specific numbers, no medical claims, acknowledges the lag effect as the surprising thing |
| 7 | Returns to app over weeks | Invested | New patterns accumulate; confidence levels upgrade from Emerging → Confirmed with more data; each return feels like a reward |

### Trust Curve
The app earns trust in a specific order: **device-local → math-first → AI-explains-only-confirmed → plain English**. Every design decision should reinforce this sequence, not shortcut it. A narration that appears before the chart breaks trust. A confidence chip that says "High" without citing n breaks trust. The "How we found this" section (deferred V1.1) is the trust-completion moment — add it early in V1.1, not late.

### 5-Second Rule
First 5 seconds of Discovery Feed: user should immediately understand they're looking at a *finding about themselves*, not a dashboard. The word "Discoveries" in the nav bar, Fraunces serif in the headline, and the specific numbers in the card body (not vague "your sleep affects your HRV") accomplish this.

## 13. Implementation Plan

| Step | Task |
|------|------|
| 1 | Add Sign in with Apple capability in Xcode; implement `ASAuthorizationAppleIDProvider` flow; store `userIdentifier` in Keychain; build Sign In SwiftUI screen |
| 2 | Set up HealthKit entitlements + HKHealthStore authorization flow in Xcode |
| 3 | Build HealthKitManager with async fetchers for 4 V1 metric types; handle partial permissions |
| 4 | Implement CorrelationEngine: Spearman via Accelerate, lag offsets, time window alignment, caching |
| 5 | Wire up Claude Haiku API with pattern narration prompt; batch results |
| 6 | Build DiscoveryFeed SwiftUI view with PatternCard, filter chips, loading, and empty states |
| 7 | Build PatternDetail view with Apple Charts scatter plot, stat row, and chart callout |
| 8 | Test on real device with own HealthKit data; verify no data leaves device; verify credential state handling |

---

## 13.5 Accessibility & Dynamic Type

### Dynamic Type
- All text uses SwiftUI's `Font.custom(_:size:relativeTo:)` with a semantic style (`.body`, `.headline`, `.caption`) so it scales with user's preferred font size
- PatternCard headline: relative to `.headline`; body: relative to `.body`; badge/chip: relative to `.caption2`
- Stat values (Geist Mono, 22pt): relative to `.title2` — scales up but does not wrap; stat cell gets taller, not wider
- At Accessibility sizes (AX1–AX5): PatternCard body truncates at 4 lines (not 3); "See full pattern" CTA remains tappable at all sizes

### VoiceOver
- **Sign In with Apple button**: system `ASAuthorizationAppleIDButton` has built-in accessibility label ("Sign in with Apple") — no custom label needed
- **Sign In screen tagline**: `accessibilityLabel("Find patterns in your health data you wouldn't notice on your own")` — read as a single unit
- **PatternCard** accessibility label: `"{Metric pair}: {headline}. Confidence: {level}."` — VoiceOver reads the full discovery in one swipe, not badge + headline + confidence separately
- **Confidence chip**: `accessibilityLabel("Confidence: High")` — not just the visual label
- **Scatter plot**: `accessibilityLabel("Scatter plot showing {metric A} on the x-axis and {metric B} on the y-axis. {N} data points. Correlation r equals {value}.")` — Apple Charts supports `chartAccessibilityLabel` modifier
- **"See full pattern" CTA**: `accessibilityHint("Opens detailed view with chart and explanation")`
- **Stat row cells**: each cell has `accessibilityLabel("{label}: {value}")` — e.g. "Correlation: r equals 0.71"
- **Loading placeholders**: `accessibilityLabel("Analyzing Sleep plus HRV patterns")` with `accessibilityValue("In progress")`

### Touch Targets
- All interactive elements ≥ 44×44pt per Apple HIG
- "See full pattern" CTA: extend tap area with `.contentShape(Rectangle())` to cover full card footer row, not just the underlined text
- Confidence chip: not interactive (display only) — no tap target needed
- Tab bar items: system TabView handles 44pt targets automatically

### Color & Contrast
- All text/background pairs in DESIGN.md meet WCAG AA (4.5:1 for body, 3:1 for large text) — verified during design system creation
- Confidence levels are never conveyed by color alone: chip always includes text label (High / Medium / Emerging)
- Error and warning states use icon + text, not color alone

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

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | — | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN (FULL) | score: 5/10 → 9/10, 3 decisions |

**UNRESOLVED:** 0 across all reviews
**VERDICT:** Design Review CLEAR — eng review required before implementation.
