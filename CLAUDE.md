# healthtrackr

## Branch naming

Always use the Linear-generated branch name for the ticket you're working on. You can find it in the `gitBranchName` field of the Linear issue.

Example: `HEA-5`, `HEA-9`

## PR titles

Use the format `TICKET-ID: Ticket title` for PR titles.

Example: `HEA-5: Project setup & configuration`

## Opening PRs after completing work

After finishing any feature, bug fix, chore, or task — always open a PR using the `/create-pr` skill. Do this automatically without waiting to be asked, unless the user explicitly says not to.

## gstack

For web browsing, always use the `/browse` skill.

If gstack skills aren't working, run `cd .claude/skills/gstack && ./setup` to rebuild.

### Available skills

- `/browse` — Headless browser for QA testing, dogfooding, and verifying deployments
- `/qa` — Full QA pass: test the app and fix issues found
- `/qa-only` — QA report only (no fixes)
- `/review` — Code review before merging
- `/ship` — Prepare and create a PR
- `/investigate` — Systematic root-cause debugging
- `/design-review` — Visual design audit + fix loop
- `/plan-design-review` — Design audit (report only)
- `/plan-eng-review` — Architecture/engineering plan review
- `/plan-ceo-review` — Strategy/product plan review
- `/office-hours` — Brainstorm and refine ideas (YC-style)
- `/design-consultation` — Design system creation
- `/document-release` — Post-ship doc updates
- `/retro` — Weekly retrospective
- `/codex` — Second opinion / adversarial code review
- `/careful` — Safety mode for production/live systems
- `/freeze` — Scope edits to one module/directory
- `/unfreeze` — Remove edit restrictions
- `/guard` — Maximum safety mode (destructive warnings + edit restrictions)
- `/canary` — Canary deployment workflow
- `/land-and-deploy` — Land and deploy workflow
- `/setup-deploy` — Set up deployment configuration
- `/setup-browser-cookies` — Import real browser cookies for authenticated testing
- `/benchmark` — Performance benchmarking
- `/gstack-upgrade` — Upgrade gstack to the latest version

## Architecture

### Swift Concurrency & Observation
- Use `@Observable` macro (not `ObservableObject`/`@Published`)
- Use `@State` to hold `@Observable` ViewModels in views (not `@StateObject`)
- Project has `default-isolation=MainActor` enabled — all types are `@MainActor` by default
- Use `async/await` exclusively — no Combine, no completion handlers
- When a default parameter needs `@MainActor` isolation (e.g., `init(healthKit: any HealthKitProviding = HealthKitManager())`), use a separate `convenience init()` instead

### Dependency Injection
- Define protocols for all external dependencies (HealthKit, networking, APIs)
- Protocol files live in `healthtrackr/Protocols/`
- Inject via initializer, not environment objects
- Conformance extensions (`extension HealthKitManager: HealthKitProviding {}`) go in the protocol file
- ViewModels take `any ProtocolName` parameters

### File Organization
```
healthtrackr/
├── Models/          — Codable structs, value types (PatternItem, MetricSample, CorrelationResult)
├── ViewModels/      — @Observable classes with business logic
├── Views/           — SwiftUI views (presentation only)
├── Engine/          — Computation (CorrelationEngine, StatisticalMath, MetricAlignment)
├── Protocols/       — Dependency protocols (one per file)
├── Services/        — External API integrations (PatternNarrator)
├── Managers/        — System integrations (HealthKitManager, AuthManager)
├── Theme/           — Design tokens (Typography, Spacing, Radius, AnimationDuration)
└── Fonts/           — Custom font files
```

### Naming
- Design token enums: `AnimationDuration` (not `Duration` — avoid shadowing stdlib)
- Utility enums for namespacing: `StatisticalMath`, `MetricAlignment`, `PatternDetailFormatter`
- Shared logic extracted into static methods on namespacing enums

### Testing
- Use Swift Testing framework (`import Testing`, `@Test`, `#expect`, `@Suite`)
- Test doubles (fakes) go at the top of the test file
- Statistical/mathematical functions must be in testable utility enums, not private on classes
- Test all state transitions in ViewModels

### Anti-patterns to Avoid
- No fire-and-forget `Task {}` wrappers around async work — make the method `async` and `await` it
- No `Task.sleep` hacks to wait for background work — `await` the actual work
- No duplicated logic across files — extract to shared utility (e.g., `MetricAlignment`)
- No nested model types in ViewModels — put models in `Models/`
- No protocols defined inside ViewModels — put in `Protocols/`

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.

All font choices, colors, spacing, border radius, and motion are defined there — including **both light and dark mode token values** for every color, component, and view.

- Never hardcode hex values in Swift — always reference named Color assets from the asset catalog
- Every color token has an `Any` (light) and `Dark` variant — use both
- Every new view must be tested in both light and dark mode before merging
- Use `@Environment(\.colorScheme)` to read system preference — never override it
- Do not deviate from DESIGN.md without explicit approval
- In QA and design-review mode, flag any code that doesn't match DESIGN.md
