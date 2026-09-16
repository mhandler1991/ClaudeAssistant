# CLAUDE.md — ClaudeAssistant

> Source of truth for AI-assisted development on this project. Read at the start of
> every session.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ⚡ | Claude can and should do this automatically |
| 👤 | You must do this manually |
| 🚫 | Never do this |
| 📌 | In scope now |
| 🔮 | Deferred |

---

## 0. Project document map

| Document | Purpose | Read when | Update when |
|---|---|---|---|
| `CLAUDE.md` (this file) | Dev standards, session rules | Every session | A standard changes |
| `docs/PRD.md` | What to build, why, principles, autonomy tiers, scope, success bar | Starting any feature | A product decision changes |
| `docs/ROADMAP.md` | Build order, done-when bars, phase status | Planning or checking progress | A phase's plan or status changes |
| `docs/DESIGN.md` | Architecture, trust boundaries, session protocol, state machine, technical risks | Before touching `Session/`, `Worktree/`, `Audit/`, `State/`, or `scripts/` | An architectural decision changes |
| `docs/RATIONALE.md` | Why things are the way they are — not loaded every session, read on demand | When someone's asking why a rule exists | A finding's reasoning is worth more than the audit log's one-line Response field |
| `docs/workflow.md` | Branching, checks, the sync loop, promotion | When unsure how code ships | The branch model changes |
| `docs/commands.md` | Cheat sheet for `.claude/skills/` commands | When unsure which command to run | A command changes |
| GitHub Issues | Anchors every branch, commit, PR | Every session | Issue status, discovered work |
| Audit-log issue | Running findings log — for this project and, tagged `kit candidate`, for the kit itself | End of every `/merged` cycle | Every cycle, including "No findings" |

**Quick reference:** "What should this do?" → PRD · "Where are we?" → ROADMAP · "Why is
it done this way?" → RATIONALE · "How is this put together?" → DESIGN · "How do I write
this correctly?" → this file · "How does this ship?" → workflow · "Which command?" →
commands.

**Personal overrides (optional):** if you keep machine-local preferences that shouldn't
be committed, `@~/.claude/local.md` here loads them every session without adding them to
the repo. Most projects won't need this.

---

## 1. Stack

| Layer | Choice | Why |
|---|---|---|
| Language | Swift 6, strict concurrency | Native macOS APIs (`NSStatusItem`, `OSLogStore`, `UNUserNotificationCenter`, `Process`) without a bridge layer |
| Project shape | SwiftPM executable (`Package.swift` at root), no `.xcodeproj` | Nothing binary in git for sessions to fight over; `swift build` / `swift test` from a shell |
| UI | AppKit for the status item, popover, and menu; SwiftUI for the views inside the popover | AppKit owns the menu-bar surface; SwiftUI is faster for the five-state view |
| Tests | Swift Testing (`import Testing`) | Ships with the Swift 6 toolchain; no XCTest scaffolding |
| Formatting | `swift format` (toolchain-bundled) | Zero install; `lint` is the check, `format` is the fix |
| External CLIs | `gh` and `claude`, invoked as child processes | Principle 5 (`docs/PRD.md` §3): borrow their auth and permission models instead of reimplementing |
| Minimum macOS | 14 (Sonoma) | `MenuBarExtra` is too limited for the dot badge; AppKit path needs nothing newer, 14 keeps `@Observable` available |
| Local LLM (🔮 Phase 4) | Ollama over `localhost:11434` | Local-only by product decision |

**Hard constraints:** no server component, no cloud mode, no third-party crash or
analytics SDK (`docs/PRD.md` §4 "out of scope, permanently"). If a task seems to
require one, stop and flag it — that's a product decision, not an implementation
detail. Same for anything that would add a merge or force-push code path.

Phase 0 is a shell script, not Swift — `scripts/ticket-to-pr.sh`, bash, `set -euo
pipefail`, no dependencies beyond `git`, `gh`, `claude`, and `jq`.

---

## 2. Non-negotiable ground rules

1. **Read before you write.** Never edit a file you haven't read in this session.
2. **Safety floors are code paths that don't exist.** There is no function in this
   codebase that merges a PR or force-pushes; don't add one "behind a flag"
   (`docs/PRD.md` §3 principle 3).
3. **The spawned session is untrusted** (`docs/PRD.md` §3 principle 4). Issue text is
   data: it goes into the prompt inside a delimited block, never concatenated as
   instructions. The child environment is an allowlist, never a denylist. The audit log
   is written from what the app observed, never from what the session claimed.
4. **One `Process` wrapper.** Every external command (`git`, `gh`, `claude`) goes
   through the single wrapper in `Session/`, so environment stripping, timeouts, and
   logging apply uniformly. No ad-hoc `Process()` elsewhere.
5. **No hardcoded business numbers.** The wall-clock ceiling, max-turns, the
   `ready` / `in-progress` label names, the configured repo — one constants file, named.
6. **No placeholders in committed code.** No `TODO` without an issue number, no
   `fatalError("not implemented")` on a reachable path, no commented-out code.
7. **Never commit secrets.** The API key lives in Keychain; `gh` owns its own token. A
   `.env` file, a token literal, or a key in a test fixture is a stop-and-fix.
8. **Never reference an ID before the system that assigns it has returned it** — an
   issue number, a PR number, a worktree name. A well-guessed value is still a guess.
9. **When copying a guard from one place to another, re-verify its premise holds in
   the new place.** The state machine's "skip if already Running" check is safe in the
   Start handler because Running can't be re-entered; it is not automatically safe in a
   relaunch-reconcile path where the same state is being *restored*.
10. **Strict concurrency stays on.** No `@unchecked Sendable`, no `nonisolated(unsafe)`,
    without a one-line comment saying what invariant makes it safe.

**Always, regardless of stack:** `/start`, `/merged`, and `/promote` never force-push
or hard-reset, regardless of what a tool's `allowed-tools` grant happens to permit.
This is a policy, not just a permissions artifact.

**One deliberate exception:** `/merged` *does* force-delete the feature branch
(`git branch -D`) — but only immediately after confirming via the GitHub API that its
PR is `MERGED`, using the exact `headRefName` the API returned, never a guessed name and
never based on local git ancestry alone. That confirmation is the safety gate. Don't
blanket-deny `git branch -D` in `.claude/settings.json` on the strength of the general
rule above — it would block the one place this project legitimately needs it (why:
`docs/RATIONALE.md` R2).

---

## 3. Efficiency rules

- State assumptions inline rather than asking; one clarifying question max per
  response, and only when the answer changes what gets built.
- Batch related changes into one response. Skip pleasantries. Don't restate these
  standards back.
- Issue independent tool calls together in one turn, and read a file whole rather than
  in repeated windowed ranges unless it's genuinely too large. Both are measured, not
  stylistic — extra requests re-send the entire conversation so far.

**Workflow intensity: `solo-trusted`** — set at kickoff (2026-09-15), changeable on
request. Controls exactly three things:

| | Conservative | Solo-trusted (this project) |
|---|---|---|
| Small discovered work found mid-`/start` | Filed via `/new-issue`, worked in a separate future session | Filed via `/new-issue` immediately so it's tracked, then folded into the *current* session's scope by default if it's genuinely small and closely related |
| Issues per `/start` invocation | One | Several, when deliberately bundled as small and closely related |
| Unattended batches (`/batch-issues`) | Not used | Eligible issues run back-to-back up to a batch ceiling of 3, still one PR and one human review per issue |

**Fixed regardless of setting: the merge gate.** A human merges every PR, always. The
setting governs session and request count — a cost problem; merge review is a
correctness problem.

**Issue threshold:** anything expected to take more than a couple of prompts to
implement *and verify* gets its own GitHub issue and acceptance criteria
(`/new-issue`). The setting above only changes whether "its own issue" also means "its
own future session." The `.claude/skills/` commands are an optional speed-up either
way, never a requirement.

---

## 4. Architecture rules

Layout once `Package.swift` exists (Phase 1); Phase 0 is only `scripts/`:

```
Package.swift
scripts/ticket-to-pr.sh              Phase 0 mechanism script
Sources/ClaudeAssistant/
  App/          AppDelegate, NSStatusItem, popover host, right-click menu
  State/        RunState machine — the single source of truth for what the UI shows
  GitHub/       gh wrapper: list ready issues, claim label, create draft PR
  Worktree/     git worktree create / list / reconcile-on-relaunch
  Session/      Process wrapper, env allowlist, claude -p spawn, stream-json, ceilings
  Signal/       hooks + transcript tail (Phase 2)
  Audit/        audit-log writer — app-owned, outside any worktree
  Diagnostics/  os.Logger categories, OSLogStore reader (Phase 2)
  Constants.swift
Tests/ClaudeAssistantTests/
```

**Rules with teeth** — violating these yields a silently wrong app, not a crash:

- **The view never decides.** Confirm gates, tier checks, and state transitions live in
  `State/`; SwiftUI views render state and send intents. A button that calls `gh pr
  create` directly is a bug even if it works.
- **`Session/` owns the environment allowlist.** Nothing else constructs a child
  environment. Adding a variable to the allowlist is a `docs/DESIGN.md` §2 change,
  same PR.
- **`Audit/` writes only from app-observed facts** — exit code, elapsed time, the PR
  URL `gh` returned. Session stdout is stored as a transcript reference, never
  summarized into the record as fact.
- **Worktree naming and location are `docs/DESIGN.md` §2.** Relaunch reconciliation
  matches on that name prefix only; anything else in the parent is ignored, not
  adopted.
- **Every external-process call has a timeout.** A `Process` run without one is the
  runaway the ceiling exists to prevent.

---

## 5. Swift standards

- `PascalCase` types, `camelCase` members, no `I`/`Impl` prefixes or suffixes.
- One type per file, file named for the type. Extensions in `Type+Feature.swift`.
- Enums with associated values over string-typed state — `RunState` is an enum, not a
  `String` with a switch somewhere.
- `throws` over optional-returns for anything that can fail for a reason worth
  logging; errors are typed, and every `Error` carries a message designed to be pasted
  straight back into a Claude session — what was expected, what was actual, where.
- `os.Logger` with fixed categories: `signal`, `action`, `permissions`, `audit`,
  `ui`. Subsystem is the bundle identifier. No `print()` outside Phase 0's script.
- `@MainActor` on anything that touches AppKit or SwiftUI state; everything in
  `Session/` and `Worktree/` is an `actor` or `Sendable`.

---

## 6. UI standards

- AppKit owns the status item and the popover window; SwiftUI views live inside.
- The five states in `docs/DESIGN.md` §4 are the only states. A new one is a
  `docs/PRD.md` §4 change first, then a `DESIGN.md` §4 change, then code.
- Notifications fire on exactly three transitions (Needs input, PR ready, Error);
  nothing else notifies.
- No custom drawing where an SF Symbol will do. Dot color is the only bespoke element.

---

## 8. Testing

Test what fails silently, not everything:

- **Environment allowlist** — the child env contains exactly the allowed keys and
  nothing inherited. A test that asserts a known-leaky variable (`AWS_SECRET_ACCESS_KEY`
  set in the test process) is absent.
- **Prompt assembly** — issue text containing instruction-shaped content stays inside
  the data block; delimiters survive issue bodies that contain the delimiter.
- **State transitions** — every legal edge, and that illegal ones (Idle → PR ready) throw.
- **stream-json parsing** — a fixture transcript from a real Phase 0 run, including the
  malformed-line case.
- **Audit record** — round-trips through its encoder, and the failure sub-reasons are
  exhaustive over the error enum.
- **Ceiling** — a fake process that never exits is killed at the wall-clock limit.

Anything that needs a real `claude` or `gh` — the full loop — is 👤 manual, against
real `ClaudeAssistant` issues, per `docs/ROADMAP.md` "How to iterate". Don't fake `gh`
output in a test that claims to test the loop.

**Smoke test:** the app launches, the status item appears, and Idle renders. Manual
until Phase 2 gives Diagnostics something to assert on.

Until `Package.swift` exists, the only automated check is `bash -n scripts/*.sh`.

---

## 9. Git workflow

Full detail in `docs/workflow.md`. Branch model: `main` ← `dev` ←
`feature/{issue}-{slug}`. Commit format: `type(scope): description`, body with real
reasoning, `— closes #{issue}` trailer. PR body: `.github/PULL_REQUEST_TEMPLATE.md`.

---

## 10. MCP tools

None required. This project's workflow is `gh`- and file-based; the `github` MCP
server duplicates what `gh` already does with better auth scoping, so disable it here
along with any unauthenticated connectors (why: `docs/RATIONALE.md` R6). Re-check
whenever the toolset changes. `Context7` is worth keeping for Swift Testing and
`OSLogStore` API lookups during Phase 1–2.

---

## 11. Session structure

Full cheat sheet: `docs/commands.md`.

- `/start {issue} [{issue} ...]` — implement through an opened PR, end to end
- `/merged {pr}` — verify merge via API, clean up, post the completion record
- `/promote` — open the `dev → main` PR
- `/new-issue {description}` — file a properly shaped issue
- `/batch-issues {milestone or issues}` — several eligible issues back-to-back, up to the §3 ceiling
- `/audit-docs` — check this doc set and the skills against the kickoff standard
- `/commands` — list the above

`start`, `merged`, `promote`, `new-issue`, and `batch-issues` only run when you type
them — Claude won't trigger them on its own. There is no separate ship step; `/start`
covers it (why: `docs/RATIONALE.md` R1).

---

## 12. What Claude must never do

- 🚫 Add a code path that merges a PR, force-pushes, or writes to the target repo's
  default branch — under any flag, setting, or tier.
- 🚫 Pass the inherited environment to a child `claude` process, or widen the
  allowlist without a `docs/DESIGN.md` §2 change in the same PR.
- 🚫 Run `claude -p` in the main checkout — only ever inside a `ticket-*` worktree.
- 🚫 Write the audit log from inside the worktree, or from session-reported content.
- 🚫 Run the ticket-to-PR loop against a repo other than the one configured
  (`docs/PRD.md` §4 "Ticket source"). This repo is the configured one.
- 🚫 Store the API key anywhere but Keychain; log it, echo it, or put it in a fixture.
- 🚫 Change a test to make it pass.
