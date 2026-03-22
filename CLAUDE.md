# healthtrackr

## Branch naming

Always use the Linear-generated branch name for the ticket you're working on. You can find it in the `gitBranchName` field of the Linear issue.

Example: `HEA-5`, `HEA-9`

## PR titles

Use the format `TICKET-ID: Ticket title` for PR titles.

Example: `HEA-5: Project setup & configuration`

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

## Design System

Always read `DESIGN.md` before making any visual or UI decisions.

All font choices, colors, spacing, border radius, and motion are defined there — including **both light and dark mode token values** for every color, component, and view.

- Never hardcode hex values in Swift — always reference named Color assets from the asset catalog
- Every color token has an `Any` (light) and `Dark` variant — use both
- Every new view must be tested in both light and dark mode before merging
- Use `@Environment(\.colorScheme)` to read system preference — never override it
- Do not deviate from DESIGN.md without explicit approval
- In QA and design-review mode, flag any code that doesn't match DESIGN.md
