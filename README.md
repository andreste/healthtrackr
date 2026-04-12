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
- An Apple Health account with at least a few weeks of data (90 days recommended for best results)
- An [Anthropic API key](https://console.anthropic.com) for AI narration (optional — the app works without it, narration falls back to a summary)

---

## Running the app

1. Clone the repo and open `healthtrackr.xcodeproj` in Xcode
2. Select your target device or simulator
3. Build and run (`⌘R`)
4. Sign in with Apple
5. Grant Health permissions when prompted
6. The app fetches and analyzes your data — this takes a few seconds on first launch

That's it. No config files, no environment variables, no build scripts.

---

## Adding your Anthropic API key (optional)

AI narration requires a Claude API key. To add one:

1. Get your key at [console.anthropic.com](https://console.anthropic.com)
2. Open the app → tap your profile icon (top right) → **Settings**
3. Under **API Key**, paste or type your key and tap **Save**

The key is stored in Keychain and never logged or transmitted anywhere other than the Anthropic API. You can remove it at any time from the same Settings screen.

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
| UI | SwiftUI, `@Observable` |
| Concurrency | Swift async/await, actors |
| Statistics | Pearson correlation, Bonferroni correction, Cohen's d |
| AI narration | Claude API (claude-haiku-4-5) |
| Auth | Sign in with Apple |
| Storage | Keychain (credentials & API key), on-disk cache with `NSFileProtectionComplete` |
| Health data | HealthKit |

---

## Privacy

- Raw health data is processed entirely on-device
- Only anonymized statistical summaries (correlation coefficients, effect sizes, sample counts) are sent to the Anthropic API for narration
- No analytics, no tracking, no third-party SDKs
