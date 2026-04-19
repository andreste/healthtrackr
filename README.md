# healthtrackr

Find patterns in your health data you wouldn't notice on your own.

healthtrackr pulls 90 days of data from Apple Health, runs statistical correlation analysis across 20 metric pairs, and uses Claude AI to narrate the patterns it finds — all on-device. Your raw health data never leaves your phone.

---

## What it does

- **Discovers correlations** across 20 pairs of health metrics (sleep & HRV, steps & resting HR, VO2 max & HRV, body mass & heart rate, and more)
- **Tests multiple time lags** (0h, 12h, 24h, 36h, 48h) to detect delayed effects — e.g. whether yesterday's exercise improves today's HRV
- **Rates confidence** (high / medium / emerging / hidden) based on Pearson r, p-value, Cohen's d effect size, and sample size
- **Narrates findings** in plain English via Claude API — a short headline and body explaining what the pattern means
- **Shows your current health data** — latest values and 7-day averages for 12 metrics across Recovery, Activity, and Fitness categories

---

## Requirements

- Xcode 16+
- iOS 18+ device or simulator
- Apple Health with at least a few weeks of data (90 days recommended for best results)
- An [Anthropic API key](https://console.anthropic.com) for AI narration (optional — the app works without it, narration falls back to a summary)

---

## Running the app

1. Clone the repo and open `healthtrackr.xcodeproj` in Xcode
2. Copy the config template and fill in your API keys (see [API key setup](#api-key-setup) below):
   ```
   cp Config.local.xcconfig.template Config.local.xcconfig
   ```
3. Select your target device or simulator
4. Build and run (`⌘R`)
5. Sign in with Apple on the splash screen
6. On the HealthKit permissions screen, tap **Grant Access** to authorize health data reading
7. The app drops you into the Discovery Feed and begins analyzing your data

**Fresh install note:** Keychain credentials from any previous install are automatically cleared on reinstall, so you'll always start fresh with Sign in with Apple.

**Simulator note:** VO2 max and walking heart rate are not available in the iOS simulator. The app handles missing metrics gracefully — those pairs are skipped during correlation analysis.

---

## API key setup

API keys are configured via xcconfig, not hardcoded or checked in. The flow is:

```
Config.local.xcconfig  →  Config.xcconfig  →  Info.plist  →  AppConfig  →  services
```

### Steps

1. Copy the template:
   ```
   cp Config.local.xcconfig.template Config.local.xcconfig
   ```
2. Open `Config.local.xcconfig` and fill in values:

   ```
   ANTHROPIC_API_KEY = sk-ant-...
   ANTHROPIC_MODEL = claude-haiku-4-5-20251001
   MIXPANEL_TOKEN = your-mixpanel-token
   ```

`Config.local.xcconfig` is gitignored and never committed.

### Anthropic API key

- Used by `PatternNarrator` to generate plain-English narration for each correlation pattern
- Get a key at [console.anthropic.com](https://console.anthropic.com)
- The xcconfig key takes precedence over any key the user enters in-app via Settings
- If neither is set, narration falls back to a static summary string

Users can also supply their own key at runtime: **Settings** (tap your initials avatar, top right) → **API Key** → enter and save. That key is stored in Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) and never logged.

### Mixpanel token

- Used by `MixpanelAnalyticsService` for app-level event tracking
- Get a token from your Mixpanel project settings
- If `MIXPANEL_TOKEN` is empty, analytics calls are no-ops (the service is conditionally compiled out)

---

## Health metrics analyzed

| Category | Metrics |
|----------|---------|
| Recovery | Sleep duration, HRV, SpO2, Respiratory rate |
| Activity | Steps, Active energy, Exercise time, Distance |
| Fitness  | Resting HR, Walking HR, VO2 max, Body mass |

---

## Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI, `@Observable` (not `ObservableObject`) |
| Concurrency | Swift async/await, `default-isolation = MainActor` |
| Statistics | Pearson correlation, Bonferroni correction, Cohen's d |
| AI narration | Claude API (`claude-haiku-4-5-20251001`) |
| Auth | Sign in with Apple (initials avatar, no profile photo) |
| Storage | Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`), on-disk cache with `NSFileProtectionComplete` |
| Health data | HealthKit |
| Analytics | Mixpanel |

### Key patterns

- ViewModels use `@Observable` + held in views with `@State` (not `@StateObject`)
- All types are `@MainActor` by default via `default-isolation = MainActor`
- All external dependencies are protocol-backed and injected via initializer
- No Combine, no completion handlers — async/await only

### Directory structure

```
healthtrackr/
├── Models/       — Codable structs, value types
├── ViewModels/   — @Observable classes with business logic
├── Views/        — SwiftUI views (presentation only)
├── Engine/       — Computation (CorrelationEngine, StatisticalMath, MetricAlignment)
├── Protocols/    — Dependency protocols (one per file)
├── Services/     — External API integrations (PatternNarrator, analytics)
├── Managers/     — System integrations (HealthKitManager, AuthManager)
├── Theme/        — Design tokens (Typography, Spacing, Radius, AnimationDuration)
└── Fonts/        — Custom font files
```

### Running tests

```
xcodebuild test -project healthtrackr.xcodeproj -scheme healthtrackr -destination 'platform=iOS Simulator,name=iPhone 16'
```

Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`).

---

## HealthKit permissions

The app requests read-only access to all 12 metrics at first launch. Required `Info.plist` keys:

- `NSHealthShareUsageDescription` — explains why health data is read
- `NSHealthUpdateUsageDescription` — required by HealthKit even though the app never writes data

The HealthKit entitlement (`com.apple.developer.healthkit`) must be present in the app's entitlements file. This is already configured in the project — no manual steps needed.

---

## Privacy

- Raw health data is processed entirely on-device
- Only anonymized statistical summaries (correlation coefficients, effect sizes, sample counts) are sent to the Anthropic API for narration
- Analytics (Mixpanel) tracks app-level events only — no health data is sent to Mixpanel
