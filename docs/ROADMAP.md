# Roadmap — ClaudeAssistant

> Build order and phase status. Product decisions live in `PRD.md` — this file assumes
> them and doesn't re-argue them.

---

## Build order

**Do not reorder** — later phases depend on earlier ones being proven. Each phase is
independently testable and leaves the project in a usable state.

### Phase 0 — Mechanism validation

A shell script, not the app: hardcoded issue number → worktree → headless Claude Code
session with a stripped environment → target repo's test command → draft PR. Lives at
`scripts/ticket-to-pr.sh` in this repo. Whatever it learns about `claude -p`,
`stream-json`, timeouts, and the FPS Roguelike test loop is what Phase 1 builds on.

**Done when:** the script has run against three different real `Rogue-Arcade` issues
and at least two of the three resulting PRs were mergeable with only minor edits.

**Milestone:** `Phase 0 - Mechanism`

### Phase 1 — Ticket to PR from the menu bar

The app shell and the full Start Ticket flow, end to end: menu-bar item with dot
badge, popover, right-click menu, five-state machine, GitHub Issues picker, claim
label, worktree creation, headless spawn with stripped env and CLI-injected API key,
runaway ceiling, test run on exit, confirm gate → push + draft PR, audit log written by
the app, notifications on Needs input / PR ready / Error. Running is a black box in
this phase (elapsed time and worktree name only) — live signal is Phase 2.

**Done when:** one full run from the menu bar, against a real `Rogue-Arcade` issue,
produces a draft PR with the push confirm gate hit exactly once and an audit-log entry
written outside the worktree.

**Milestone:** `Phase 1 - Ticket to PR`

### Phase 2 — Live signal and diagnostics

Hooks + transcript tail attach at spawn (the daemon-tails-transcript pattern), driving
the Running state with what the session is actually doing. Diagnostics tab reads the
app's own `os.Logger` output via `OSLogStore`. Minimum interruption handling: on
relaunch, reconcile against existing `ticket-*` worktrees rather than losing them.

**Done when:** during a real run, the popover shows the current tool call / file
touched within ~1s of it appearing in the transcript, and the Diagnostics tab shows
the `signal` / `action` / `permissions` categories for that run — and the POC success
bar in `PRD.md` §5 (three consecutive UI-driven runs, two of three mergeable) has been
cleared.

**Milestone:** `Phase 2 - Live signal`

### Phase 3 — Hardening

Only what real POC runs demanded, in the order they demanded it. Candidates, each
un-deferred by its `PRD.md` §4 trigger: single automatic retry designed against real
failure logs; permissions settings UI with per-project overrides; fuller interruption
recovery; worktree pruning; auth-expiry / rate-limit surfaced distinctly in the UI.
Acceptance criteria land on the issues when each is sharpened, not here.

**Done when:** every failure mode observed during the POC runs either has a fix
observed working or an issue with a repro.

**Milestone:** `Phase 3 - Hardening`

### Phase 4 — Interpretation layer (dev signal only)

Local LLM via Ollama (endpoint: `CLAUDE.md` §1) reads the hook/transcript stream and
produces
observations ("same test failed 4 times", "session has been in a fix-run-fail loop for
12 minutes"). Surfaced in the popover as banners. No general-activity signal yet.

**Done when:** the app surfaces at least one observation from a real session that
Max didn't hand-prompt for and that names a pattern he recognizes as real.

**Milestone:** `Phase 4 - Interpretation`

### Phase 5 — General-activity signal and fusion

App/window foreground, browser tab, calendar — via macOS Accessibility / Screen
Recording APIs, modeled on ActivityWatch's event schema — fed into the same
interpretation layer as Phase 4. This is where the `PRD.md` §2 thesis starts existing.
Persistence gets built here only if a fusion feature needs yesterday's data.

**Done when:** an observation that *requires both* streams (e.g. "6 context switches
mid-debug-loop") is surfaced from a real working day.

**Milestone:** `Phase 5 - Fusion`

### Beyond — not phases yet

Suggestion-delivery maturity (digests, tone/frequency tuning), notch-island UI, and
the live-call-feedback signal source are all deferred in `PRD.md` §4 with their
triggers. None gets a milestone until its trigger fires and it's sharpened into a
phase here.

---

## Current status

**Active: Phase 0.** Nothing built yet. First job is `scripts/ticket-to-pr.sh` and
three real runs against `Rogue-Arcade`.

```bash
gh issue list --milestone "Phase 0 - Mechanism"    # what this phase still owes
```

---

## How to iterate

Run the loop against real `Rogue-Arcade` issues, not synthetic ones — the success bar
is about real PRs, and synthetic issues hide the prompt-assembly and test-command
problems that matter. After each run, read the audit-log entry and the transcript
before touching code; the failure sub-reason is the thing to fix, not the UI state
that displayed it.

Never ship a fix that hasn't been observed working, and say plainly when a fix is
inferred rather than confirmed — so the next session targets the right thing instead
of confirming a guess that was never actually checked. A confidently-stated fix that
was never observed to work is worse than one honestly labeled as unverified.
