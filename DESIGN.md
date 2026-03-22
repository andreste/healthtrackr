# Design System — healthtrackr

## Product Context

- **What this is:** An iOS pattern detective app that surfaces non-obvious cross-metric health insights from HealthKit
- **Who it's for:** Personal use — iOS users with 30–90 days of Apple Health data
- **Space/industry:** Health analytics / quantified self
- **Project type:** iOS app (SwiftUI)

---

## Aesthetic Direction

- **Direction:** Editorial / Investigative
- **Decoration level:** Minimal — typography and whitespace do the work. No gradients, no blobs.
- **Mood:** Discoveries feel like dispatches from your body's analyst. Intelligent, readable, confident. Not a medical dashboard — something you actually want to read.
- **Deliberate departures from category norms:**
  1. Warm off-white (light) / warm near-black (dark) backgrounds — every competitor uses cold dark mode. We follow system preference and both modes feel warm and considered.
  2. Fraunces serif for discovery headlines — the entire health app category is sans-serif. A variable serif signals "this is a finding worth reading."
  3. Deep amber accent — health apps universally use teal/green. Amber reads warm, investigative, confident.

---

## Color Mode

**Follows system preference.** SwiftUI implementation: use `Color` asset catalog with `Appearance: Any, Dark` variants for every token. Never hardcode hex values in Swift — always reference named Color assets or semantic SwiftUI colors.

```swift
// Correct
Text("Discovery").foregroundStyle(Color("textPrimary"))

// Never do this
Text("Discovery").foregroundStyle(Color(hex: "#1A1814"))
```

---

## Color Tokens

Every token has both a light and dark value. Dark mode is not an inversion — surfaces stay warm, accent desaturates slightly to avoid blow-out on dark backgrounds.

### Backgrounds & Surfaces

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `bgPrimary` | `#F7F5F2` | `#141210` | App background, screen base |
| `bgCard` | `#FFFFFF` | `#1F1C19` | Cards, discovery cards, sheets |
| `bgSubtle` | `#EEEAE4` | `#2A2620` | Narration boxes, stat row bg, muted sections |
| `bgElevated` | `#FFFFFF` | `#272320` | Modal sheets, overlays |

### Text

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `textPrimary` | `#1A1814` | `#F0EDE8` | Body copy, card headlines, primary labels |
| `textSecondary` | `#6B6560` | `#A09A94` | Supporting text, card body, descriptions |
| `textTertiary` | `#A09A94` | `#6B6560` | Timestamps, footnotes, placeholder text |
| `textOnAccent` | `#FFFFFF` | `#FFFFFF` | Text on accent-colored buttons/badges |

### Borders & Dividers

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `borderDefault` | `#E4E0D8` | `#302C27` | Card borders, dividers, input outlines |
| `borderStrong` | `#C8C3BA` | `#453F38` | Focused inputs, featured card borders |
| `borderSubtle` | `#EEEAE4` | `#242018` | Section separators, subtle dividers |

### Accent

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `accentPrimary` | `#C4622D` | `#D4744A` | Primary buttons, active tabs, links, confidence fill |
| `accentLight` | `#F5E6DC` | `#2A1E14` | Badge backgrounds, button hover bg, selected chip bg |
| `accentDark` | `#9E4D22` | `#E8906A` | Button pressed state, accent text on light bg |

### Semantic

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `semanticSuccess` | `#2D7D46` | `#4CAF72` | High confidence indicators, data confirmed |
| `semanticSuccessBg` | `#F0FAF4` | `#0F2018` | Success alert backgrounds |
| `semanticWarning` | `#B8860B` | `#D4A520` | Emerging patterns, medium confidence |
| `semanticWarningBg` | `#FFFBEA` | `#201800` | Warning alert backgrounds |
| `semanticError` | `#C4362A` | `#E05A50` | HealthKit denied, data errors |
| `semanticErrorBg` | `#FFF1F0` | `#1E0A08` | Error alert backgrounds |
| `semanticInfo` | `#2B5EA7` | `#5B8FD4` | Neutral informational states |
| `semanticInfoBg` | `#EFF4FD` | `#0A1528` | Info alert backgrounds |

### Confidence Levels (specialized)

| Confidence | Light fill | Dark fill | Label color (both modes) |
|------------|-----------|-----------|--------------------------|
| High (p < 0.01) | `#C4622D` | `#D4744A` | `semanticSuccess` |
| Medium (p < 0.05) | `#B8860B` | `#D4A520` | `semanticWarning` |
| Emerging (n < 30) | `#A09A94` | `#6B6560` | `textTertiary` |

---

## Typography

Three distinct registers — each tied to a job, not just a size.

### Fonts

| Role | Font | Fallback | Rationale |
|------|------|----------|-----------|
| **Display / Discovery headlines** | Fraunces (variable, opsz 9–144) | Georgia, serif | Editorial weight. Signals "this is a finding worth reading." Every health competitor uses sans-serif. |
| **Body / Narrative paragraphs** | Instrument Sans | system-ui, sans-serif | Clean, legible, modern. AI explanations read comfortably at 14–16pt. |
| **Data / Stats / Labels** | Geist Mono | JetBrains Mono, monospace | Sharp, technical. `tabular-nums` feature for r=0.71, p<0.05, −18% values. Reads as precise. |

### Loading (iOS)

Register all three fonts in `Info.plist` under `UIAppFonts`. Use `CTFontDescriptor` for Fraunces variable axis (optical size). Instrument Sans and Geist Mono are static weights — include only the weights used.

**Fraunces variable axes used:**
- `opsz`: 9 (compact UI labels) → 72 (large display)
- `wght`: 400 (body italic) → 600 (headlines)
- `SOFT`: leave at default (0) for editorial crispness

### Type Scale

| Level | Font | Size | Weight | Line height | Usage |
|-------|------|------|--------|-------------|-------|
| `displayXL` | Fraunces | 42pt | 600 | 1.1 | App hero, onboarding headline |
| `displayLG` | Fraunces | 28pt | 550 | 1.2 | Screen titles |
| `displayMD` | Fraunces | 22pt | 500 | 1.25 | Discovery card headline (featured) |
| `displaySM` | Fraunces | 18pt | 500 | 1.3 | Discovery card headline (standard) |
| `displayItalic` | Fraunces italic | 16pt | 400 | 1.35 | Subheadings, supporting discovery context |
| `bodyLG` | Instrument Sans | 16pt | 400 | 1.6 | Primary narrative/explanation paragraphs |
| `bodyMD` | Instrument Sans | 14pt | 400 | 1.55 | Card body text, standard copy |
| `bodySM` | Instrument Sans | 13pt | 400 | 1.5 | Supporting text, timestamps, footnotes |
| `labelMD` | Instrument Sans | 13pt | 600 | 1.4 | Buttons, CTAs, UI labels |
| `labelSM` | Instrument Sans | 11pt | 600 | 1.3 | Chip labels, badge text |
| `dataLG` | Geist Mono | 28pt | 500 | 1.1 | Primary stat values (r-value, effect size) |
| `dataMD` | Geist Mono | 18pt | 400 | 1.2 | Stat row values |
| `dataSM` | Geist Mono | 12pt | 400 | 1.4 | Inline stats (p<0.01, n=14), timestamps |
| `dataXS` | Geist Mono | 10pt | 400 | 1.3 | Axis labels, confidence level badges |

### Letter Spacing

- Fraunces display: `-0.02em` (tighten for headlines)
- Instrument Sans body: `0` (default)
- Geist Mono: `0` for numbers, `+0.05em` for ALL-CAPS labels

---

## Spacing

**Base unit: 8px.** All spacing values are multiples of 4px (half-step allowed for tight UI).

| Token | Value | Usage |
|-------|-------|-------|
| `space1` | 4px | Tight inline gaps (badge padding, icon gap) |
| `space2` | 8px | Default inline gap, small component padding |
| `space3` | 12px | Component internal spacing (chip padding) |
| `space4` | 16px | Card section spacing, list item padding |
| `space5` | 24px | Card internal padding (standard) |
| `space6` | 32px | Between cards in feed |
| `space7` | 48px | Section breaks |
| `space8` | 64px | Screen-level vertical breathing room |

**Density:** Comfortable. Cards breathe at 24px internal padding. Tight is 16px (stat rows). Never go below 12px for tappable elements.

---

## Layout

- **Approach:** Grid-disciplined — consistent 16px gutters, strong vertical rhythm. Cards are confident rectangles, not rounded bubbles.
- **Screen horizontal margin:** 16pt (matches iOS system standard)
- **Card layout:** Full-width minus 2× screen margin. No multi-column card layout on iPhone.
- **Max tap target:** Minimum 44×44pt (Apple HIG requirement)

### Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radiusXS` | 4pt | Badges, chips, confidence bars |
| `radiusSM` | 6pt | Input fields, small buttons |
| `radiusMD` | 10pt | Cards, discovery cards, narration boxes |
| `radiusLG` | 16pt | Sheets, modals |
| `radiusFull` | 9999pt | Pills, toggle switches |

**Note:** Avoid the "bubbly" look (uniform large radius on everything). Discovery cards use `radiusMD` (10pt) — confident, not soft.

---

## Components

### Discovery Card (primary component — light and dark)

**Light mode:**
- Background: `bgCard` (#FFFFFF)
- Border: `borderDefault` (#E4E0D8), 1pt
- Featured card border: `accentPrimary` (#C4622D), 1.5pt
- Headline: `displayMD` Fraunces, `textPrimary`
- Body: `bodyMD` Instrument Sans, `textSecondary`
- Badge bg: `accentLight` (#F5E6DC), border `accentPrimary`
- Confidence fill: level-appropriate color (see Confidence Levels above)
- CTA: `accentPrimary` (#C4622D)

**Dark mode:**
- Background: `bgCard` (#1F1C19)
- Border: `borderDefault` (#302C27)
- Featured card border: `accentPrimary` (#D4744A)
- Headline: `textPrimary` (#F0EDE8)
- Badge bg: `accentLight` (#2A1E14), border `accentPrimary` (#D4744A)
- CTA: `accentPrimary` (#D4744A)

### Confidence Bar

- Track: `bgSubtle` in both modes
- Fill: confidence-level color (High=accent, Medium=warning, Emerging=tertiary)
- Label: `dataXS` Geist Mono, `textTertiary`
- Height: 3pt, `radiusFull`

### Stat Row

- Container border: `borderDefault`, `radiusMD`
- Cell divider: `borderDefault`
- Value: `dataMD` Geist Mono, `textPrimary`
- Label: `dataXS` Geist Mono, `textTertiary`
- Background: transparent (inherits card bg)

### Narration Box (AI explanation)

- Background: `bgSubtle` in both modes
- Eyebrow: `dataXS` Geist Mono, `textTertiary`, ALL-CAPS, +0.08em tracking
- Text: `bodyMD` Instrument Sans italic, `textPrimary`
- Radius: `radiusXS` (4pt) — tighter than cards, feels like an inset block

### Buttons

| Variant | Light bg | Light text | Dark bg | Dark text |
|---------|----------|------------|---------|-----------|
| Primary | `accentPrimary` #C4622D | #FFFFFF | `accentPrimary` #D4744A | #FFFFFF |
| Secondary | `bgSubtle` #EEEAE4 | `textPrimary` | `bgSubtle` #2A2620 | `textPrimary` |
| Ghost | transparent | `accentPrimary` | transparent | `accentPrimary` |

- Font: `labelMD` Instrument Sans 600
- Radius: `radiusSM` (6pt)
- Padding: 10pt vertical, 18pt horizontal
- Pressed state: 0.95 scale + 0.1s ease

### Metric Chips (filter row)

| State | Light | Dark |
|-------|-------|------|
| Default | border `borderDefault`, text `textTertiary` | border `borderDefault` (#302C27), text `textTertiary` |
| Active | border `accentPrimary`, text `accentPrimary`, bg `accentLight` | border `accentPrimary` (#D4744A), text `accentPrimary`, bg `accentLight` (#2A1E14) |

- Font: `dataXS` Geist Mono 500
- Radius: `radiusFull` (pill)
- Padding: 4pt vertical, 10pt horizontal

### Badges

| Variant | Light | Dark |
|---------|-------|------|
| Default | border `borderDefault`, text `textTertiary`, bg transparent | same with dark border/text |
| Accent | border `accentLight`, text `accentPrimary`, bg `accentLight` | border `accentLight` (#2A1E14), text `accentPrimary` (#D4744A), bg `accentLight` |
| Warning | border `#B8860B40`, text `semanticWarning`, bg `semanticWarningBg` | dark equivalents |

- Font: `dataXS` Geist Mono 500, ALL-CAPS, +0.06em tracking
- Radius: `radiusXS` (4pt)
- Padding: 3pt vertical, 7pt horizontal

### Inputs

| State | Light border | Dark border |
|-------|-------------|-------------|
| Default | `borderDefault` #E4E0D8 | `borderDefault` #302C27 |
| Focused | `accentPrimary` #C4622D | `accentPrimary` #D4744A |
| Error | `semanticError` #C4362A | `semanticError` #E05A50 |

- Background: `bgCard` in both modes
- Text: `textPrimary`, placeholder `textTertiary`
- Label: `labelSM` Instrument Sans 600, `textSecondary`
- Font: `bodyMD` Instrument Sans
- Radius: `radiusSM` (6pt)
- Padding: 10pt vertical, 14pt horizontal

### Alerts / Banners

Each has a dedicated `semanticXxxBg` token for both modes (see Color Tokens above). Left border = 3pt semantic color. Text uses semantic color at darkened/lightened value for readability on the bg.

### Tab Bar

- Active tab icon + label: `accentPrimary`
- Inactive: `textTertiary`
- Background: `bgCard` with top border `borderSubtle`
- Font: `dataXS` Geist Mono 500

---

## Motion

- **Approach:** Minimal-functional — only transitions that aid comprehension
- **Easing:** enter `easeOut` · exit `easeIn` · move `easeInOut`
- **Duration scale:**

| Token | Duration | Usage |
|-------|----------|-------|
| `durationMicro` | 80ms | Button press feedback, tap states |
| `durationShort` | 180ms | Card appear, chip selection |
| `durationMedium` | 280ms | Screen transitions, sheet presentation |
| `durationLong` | 450ms | Confidence bar fill on first load |

- **Specific animations:**
  - Discovery cards: slide up + fade in on first load (`durationShort`, `easeOut`, staggered 60ms per card)
  - Confidence bar: width animates from 0 on card appear (`durationLong`, `easeOut`)
  - Button press: scale 0.95, `durationMicro`, `easeOut`
  - Tab switch: crossfade, `durationShort`
- **No decorative motion:** No looping animations, no scroll-driven parallax, no bouncy physics. This is a precision instrument.

---

## Dark Mode Implementation Notes (SwiftUI)

1. **Use Color asset catalog** — create every token as a named Color asset with `Any` (light) and `Dark` appearance variants. Never use `UIColor(light:dark:)` inline.
2. **`.colorScheme` environment** — read system preference, do not override it in the app.
3. **Adaptive images** — any icons or illustrations with color fills need light/dark variants in the asset catalog.
4. **Shadows in dark mode** — use `Color.black.opacity(0.3)` instead of `Color.black.opacity(0.08)` for card shadows on dark bg. Shadows are nearly invisible on dark surfaces — use borders instead.
5. **Test on both** — every new view must be tested in both light and dark mode before merging. Use Xcode's canvas environment override.

---

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-22 | Fraunces serif for discovery headlines | Differentiates from all-sans health app category; editorial voice matches "pattern detective" concept |
| 2026-03-22 | Deep amber accent (#C4622D / #D4744A) | Avoids health-category teal/green; warm and investigative; consistent with editorial aesthetic |
| 2026-03-22 | Warm off-white bg (#F7F5F2) in light, warm near-black (#141210) in dark | Both modes stay warm; avoids cold clinical feel of competitors |
| 2026-03-22 | System preference for light/dark mode | Personal iOS app should respect system setting; SwiftUI ColorScheme environment handles this natively |
| 2026-03-22 | Geist Mono for all data/stat values | Tabular-nums alignment for r-values, p-values, percentages; technical precision signal |
| 2026-03-22 | radiusMD = 10pt for cards (not bubbly) | Confident rectangle energy; distinguishes from rounded-everything health app aesthetic |
| 2026-03-22 | Minimal motion only | Precision instrument — no decorative animation; trust is built through data, not delight |
