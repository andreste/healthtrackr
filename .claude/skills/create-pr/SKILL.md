---
name: create-pr
description: Create a PR for the current branch using the Linear ticket title as the PR title. Fetches the ticket details, builds a summary and writes a test plan. Do not include the screenshots section if there are no screenshots to take.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - mcp__linear-server__get_issue
  - mcp__linear-server__list_issues
---

# Create PR

## Steps

### 1. Identify the Linear ticket

Get the current branch name:

```bash
git branch --show-current
```

Extract the ticket ID from the branch name (e.g. `HEA-34` from `hea-34-add-keychain-access`).

If the ticket ID is not clear from the branch name, use AskUserQuestion to ask the user.

### 2. Fetch the Linear ticket

Use `mcp__linear-server__get_issue` with the ticket ID (e.g. `HEA-34`) to get:
- `title` — used as the PR title suffix
- `description` — used to understand the scope of the change

PR title format: `TICKET-ID: Ticket title`
Example: `HEA-34: Add Keychain access control attributes`

### 3. Summarize the diff

```bash
git diff main...HEAD --stat
git log main...HEAD --oneline
```

Read the changed files to understand what was built. Write a concise bullet-point summary (3–5 bullets) covering:
- What was added or changed
- Why (link back to the ticket goal)
- Any notable technical decisions

### 4. Write the test plan

Based on the ticket description and diff, write a markdown checklist for manual QA covering:
- Happy-path scenarios
- Edge cases or error states
- Regression checks (existing flows that should still work)

### 5. Create the PR

```bash
gh pr create \
  --title "<TICKET-ID>: <Ticket title>" \
  --body "$(cat <<'BODY'
## Summary

- <bullet 1>
- <bullet 2>
- <bullet 3>

## Screenshots

| Before | After |
|--------|-------|
| _(n/a)_ | <screenshot or description> |

<img width="300" src="<screenshot-url-1>" />
<img width="300" src="<screenshot-url-2>" />

## Test Plan

- [ ] <test step 1>
- [ ] <test step 2>
- [ ] <test step 3>
BODY
)"
```

Substitute the actual ticket ID, title, summary bullets, and test plan steps.

After the PR is created, print the PR URL.
