---
description: Open the dev → main promotion PR
disable-model-invocation: true
allowed-tools: Bash(git checkout:*), Bash(git pull:*), Bash(git log:*), Bash(gh pr create:*), Bash(swift build:*), Bash(swift format lint:*), Bash(swift test:*), Bash(bash -n:*)
---

# Promote dev → main

## Before

- Switch to dev: !`git checkout dev`
- Pull latest: !`git pull origin dev`
- Recent history: !`git log --oneline -10`
- Commits ahead of main: !`git log --oneline origin/main..origin/dev`

(Four separate single-command injections — no `&&` or `|` anywhere in this file.)

## Sequence

1. **Confirm checks are green on `dev`** before opening anything — a red integration
   branch never gets promoted. If CI exists, read it; if not (pre-`Package.swift`),
   run the checks locally as separate commands:
   ```bash
   swift build
   ```
   ```bash
   swift format lint --recursive Sources Tests
   ```
   ```bash
   swift test
   ```
   ```bash
   bash -n scripts/ticket-to-pr.sh
   ```
2. **Open the PR** from `dev` into `main`, using the promotion shape at the bottom of
   `.github/PULL_REQUEST_TEMPLATE.md` — a one-line summary of what's included, plus
   the tag reminder.
3. **Do not merge or tag it yourself.** Report the PR URL and stop.

👤 After you merge: tag the release (`v0.{phase}.{patch}`) and
`git push origin main --tags`. Tags are the rollback handle — deliberately not
automated.
