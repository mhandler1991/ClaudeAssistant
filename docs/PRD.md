# PRD — ClaudeAssistant

> A macOS menu-bar assistant that turns a labeled GitHub issue into a reviewed draft
> PR via an isolated, headless Claude Code session — and is built to grow into a
> local "how you work" coaching layer that fuses dev-tool signal with general
> computer-activity signal.

Product decisions only. Build order and phase status: `ROADMAP.md`. Architecture and
security posture: `DESIGN.md`. This file changes when a **product decision** changes.

---

## 1. What this is

A single-user macOS menu-bar app. In its first shipping form it does one thing: you
pick a `ready`-labeled GitHub issue, it claims the issue, spawns a headless Claude
Code session in a fresh git worktree, shows you the session live, runs the project's
tests, and — only after you confirm — pushes the branch and opens a draft PR. It never
merges.

Its long-term shape is a local, always-on interpretation layer over two signal
streams nobody currently fuses: structured Claude Code activity (files touched, tool
calls, errors, session shape) and general computer activity (app/window switches,
browser tabs, calendar). The ticket-to-PR loop is the first concrete thing that
layer can *act* on; the fusion thesis is what it's architected toward.

### What it is not

- **Not a local-LLM chat client.** Ollamac and friends already exist; no general chat
  UI is planned.
- **Not a general activity tracker.** Rize and ActivityWatch already exist; if
  general-activity signal is built, it borrows ActivityWatch's schema rather than
  competing.
- **Not a CI/cloud ticket-automation platform.** claude-surf and claude-linear own
  that shape (webhook-triggered, hosted). This is a personal, local, always-on app —
  the agent-role split and worktree-per-ticket model are borrowed from them, not
  re-differentiated.
- **Not a team tool.** One user, one machine, one repo at a time, for the foreseeable
  future. The moment a collaborator, bot, or public issue tracker enters the picture,
  the trust boundary (§4, "Autonomy tiers") has to be redesigned, not extended.

---

## 2. Why it exists

Two frictions, one immediate and one structural:

- **Immediate:** small, well-specified tickets on the FPS Roguelike repo
  (`Rogue-Arcade`) still cost a manual ritual — branch, worktree, write the prompt,
  babysit the session, run tests, open the PR. Existing Claude Code monitors (CC
  Monitor, Claude Status Bar, Claude Statistics) can *show* a session but can't
  *start* one or carry it through to a PR.
- **Structural:** general activity coaches see the shape of a day but not the
  substance of a dev session (Claude Code is just "Terminal" to Rize); dev-session
  monitors see the substance but not the day around it. Nobody puts both in one
  LLM-driven interpretation layer. That fusion is the bet — untested until real
  dogfooding, which is why it's deliberately *not* what ships first.

---

## 3. Principles

> These decide arguments. When a feature conflicts with one of these, the principle
> wins.

1. **Mechanism before surface.** Prove a loop works as a script before building UI
   for it. *Why:* Phase 0 exists because UI built on an unproven mechanism is the most
   expensive way to find out it doesn't work.
2. **Every deferral has a named trigger, not a phase number.** Storage waits for
   cross-session learning; retry waits for real failure logs; the settings UI waits
   for a second project. *Why:* preemptive infrastructure is how this project's scope
   crept from "menu-bar monitor" to "call-feedback engine" before a line of code
   existed.
3. **Safety floors are code, not settings.** Never auto-merge, never force-push
   `main`, always confirm anything hard to reverse — hardcoded so a settings bug can't
   disable them. *Why:* one bad autonomous action ends trust in the whole automation,
   even if the underlying fix is small.
4. **The spawned session is untrusted.** Issue content is data, not instructions; the
   child process gets a stripped environment and a single-repo token; the audit log
   is written by the app, never self-reported by the session. *Why:* worktree
   isolation protects git state, not the machine.
5. **Borrow the solved parts.** Transcript-tail daemon, worktree-per-ticket, Claude
   Code's own permission model — reuse, don't rebuild. The differentiator is the
   fusion layer; nothing upstream of it is. *Why:* if POC infrastructure runs
   meaningfully past estimate, that's the signal to adapt claude-surf's mechanism,
   not to keep going from scratch.

---

## 4. Scope

### In scope

| Area | What |
|---|---|
| Ticket source | GitHub Issues on one configured repo, filtered by a `ready` label; already-started tickets (per the audit log) aren't re-offered |
| Claim | Apply `in-progress` to the issue on start — visible outside the app, prevents double-starting by hand or by a second instance |
| Isolation | One fresh git worktree + branch per ticket, off the default branch |
| Session | Headless Claude Code (`claude -p … --output-format stream-json`) inside the worktree, with the issue title/body/comments assembled as the prompt and the target repo's `CLAUDE.md` referenced for conventions |
| Runaway ceiling | Wall-clock timeout (~20 min to start) and max-turns; either tripping kills the session and surfaces Error |
| Live visibility | Hooks + transcript tail attach at spawn, so Running is a live view, not a black box |
| Completion | Run the target repo's test command if defined; pass → confirm gate; fail → Error, logged, stop |
| Confirm gates | Push + draft PR (`gh pr create --draft`) only after explicit confirm; merge is never offered |
| Audit log | Structured record per run, written by the app process outside the worktree: ticket, worktree, tier decisions, outcome, PR link, internal failure sub-reason (`task_failure` / `auth_expired` / `rate_limited`) |
| UI | Menu-bar glyph + color dot, popover, right-click quick menu, five states (Idle / Running / Needs input / PR ready / Error), macOS notifications on Needs input, PR ready, Error |
| Diagnostics | In-app view of the app's own `os.Logger` output via `OSLogStore` |
| Concurrency | One session at a time; Start disabled while one is active |

### Autonomy tiers

Two layers, composed: the app's own action tiers below, and Claude Code's
session-level tool permissions (`settings.json` allow/ask/deny), which the app passes
into the spawned session rather than reimplementing.

| Tier | Examples | Default |
|---|---|---|
| Read-only | View ticket status, session history, PR state | Always allowed |
| Reversible, isolated | Clear/compact context, spawn session in fresh worktree, pick up ticket, run local tests | Auto-allow |
| Externally visible, reversible | Push branch, open draft PR, comment on GitHub | Confirm (per-project auto toggle is deferred) |
| Hard to reverse | Merge PR, force-push, close ticket, touch `main` directly | Always confirm |

**Non-configurable floors:** never auto-merge, never force-push `main`. These are
hardcoded (principle 3).

**Trust boundary, stated plainly:** the `ready` label is the de facto access-control
boundary — whoever can label an issue can direct a privileged agent at the repo.
Today only collaborators on the repo can apply labels, and there's one, so it's
vacuous. It stops being vacuous the moment anyone else can label issues; that's a
redesign, not a setting.

### Out of scope, permanently

- Auto-merging any PR, or force-pushing to `main`, under any setting
- A hosted/cloud mode, or any server component
- A general-purpose chat UI over the local LLM
- Multi-user or team features (shared queues, per-user permissions)
- Third-party crash reporting or cloud logging
- App Store distribution, notarization, or code signing for the foreseeable future

### Deferred

| Item | Why deferred (the trigger that un-defers it) |
|---|---|
| Automatic single retry on task failure | Needs real POC failure logs to design a retry prompt that isn't a guess |
| Permissions settings UI + per-project overrides | Hardcoded conservative defaults are enough for one repo; a second project is the trigger |
| Local-LLM interpretation layer (dev signal) | The action loop has to be trustworthy first; observations layered on an unproven loop would be noise |
| General-activity signal + fusion with dev signal | This is where the thesis actually lives — but it's worthless without a dev-signal stream that's already reliable |
| Persistence / cross-session pattern learning | In-memory is sufficient until a feature needs yesterday's data; that need is the trigger |
| Notch-island always-visible surface | Only justified if click-to-confirm via the popover proves too slow in real use |
| Live-call-feedback engine (call audio as a new signal source) | Same pipeline, different signal — exploratory, crowded category (Cluely et al.), not touched until the fusion layer exists |
| Full interruption recovery (crash / sleep / network drop mid-session) | POC does the minimum — reconcile against existing worktrees on relaunch; the full flow waits for observed failure modes |
| Worktree pruning | Disk usage isn't a problem until it is; a real "disk full of `ticket-*` worktrees" is the trigger |

---

## 5. Success

**The bar:** three consecutive ticket-to-PR runs, driven entirely through the
menu-bar UI against three different real `Rogue-Arcade` issues, where at least two of
the three resulting PRs are mergeable with only minor edits.

Secondary signals:

- Phase 0's script clears the same 2-of-3 bar before any app code is written — if it
  doesn't, the mechanism gets revisited, not the UI.
- The audit log shows zero tier-4 actions taken without a confirm, across every run.
- Reviewing an AI-generated PR is observably cheaper than writing the change by hand —
  the whole ROI case assumes this and it's currently untested.

---

## 6. Known product risks

Technical and security risks live in `DESIGN.md` §7. These are the product-level ones.

| Risk | Current standing |
|---|---|
| Scope creep / never shipping | The single biggest observed risk in this project's own planning history. Containment: Phase 0 → POC sequence in `ROADMAP.md`, principle 2, and the success bar above. |
| Fusion thesis unproven | Plausible, untested. Won't be validated by more planning — only by dogfooding after the action loop is trustworthy. |
| Trust erosion from one bad autonomous action | Mitigated by principle 3 and the audit log; not eliminable. |
| Confirm-gate fatigue | Once the loop is reliable, the natural response is to stop reading diffs carefully — exactly when a subtle bad diff is most likely to land. No mitigation yet beyond awareness. |
| Reinventing claude-surf, slower | If POC infrastructure runs meaningfully past the ~7–9 focused-day estimate, adapt claude-surf's mechanism rather than finishing a from-scratch equivalent (principle 5). |
| Review-time assumption | The ROI case assumes reviewing an AI PR beats writing by hand; measured for the first time by the success bar. |
