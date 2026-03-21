# MyFirstApp

## Branch naming

Always use the following prefixes when creating branches:

- `feature/` — new feature
- `bugfix/` — bug fix
- `chore/` — maintenance, dependencies, tooling
- `docs/` — documentation changes
- `refactor/` — code restructuring without behavior change
- `hotfix/` — urgent production fix

Example: `feature/user-authentication`, `bugfix/login-crash`, `docs/update-readme`

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
