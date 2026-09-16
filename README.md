# ClaudeAssistant

A macOS menu-bar app for one person. Pick a `ready`-labeled GitHub issue; it spawns a
headless Claude Code session in an isolated git worktree, shows you the session live,
runs the project's tests, and — only after you confirm — pushes the branch and opens a
draft PR. It never merges.

Runs locally, from a plain `swift build` — no App Store, no notarization, no server.

---

## What it does

- Lists `ready`-labeled issues on one configured GitHub repo and claims the one you pick
- Creates a fresh git worktree + branch per ticket, off the default branch
- Runs `claude -p` headlessly inside the worktree with a stripped environment and a
  runaway ceiling (wall-clock + max-turns)
- Runs the target repo's test command; only a passing run reaches the confirm gate
- Pushes and opens a **draft** PR after you explicitly confirm
- Writes a structured audit-log entry per run, outside the worktree
- Menu-bar glyph + color dot, popover, five states, macOS notifications

## What it deliberately does not do

- Auto-merge, or force-push to `main` — hardcoded, not a setting
- Run in the cloud, or have any server component
- Offer a general chat UI over a local LLM
- Support more than one user, one machine, one repo at a time
- Track general computer activity — yet; that's a later phase, built on
  ActivityWatch's schema rather than competing with it

Full scope, principles, and deferrals: [`docs/PRD.md`](docs/PRD.md).

---

## Getting started

Requirements: macOS 14+, Xcode command-line tools with Swift 6, `gh` (authenticated),
`claude` (Claude Code CLI). Ollama is only needed from Phase 4.

Build and run:

```bash
swift build
swift run ClaudeAssistant
```

Checks:

```bash
swift build
swift format lint --recursive Sources Tests
swift test
```

Until `Package.swift` exists (the first Phase 1 issue creates it), the only thing to
run is Phase 0's script, `scripts/ticket-to-pr.sh` — see
[`docs/ROADMAP.md`](docs/ROADMAP.md) for where the build order currently stands.

---

## Documentation

| File | What it covers |
|---|---|
| `CLAUDE.md` | Development standards and the doc map |
| `docs/PRD.md` | What we're building, why, principles, scope, success bar |
| `docs/ROADMAP.md` | Build order, done-when bars, phase status |
| `docs/DESIGN.md` | Architecture, trust boundaries, session protocol, state machine |
| `docs/RATIONALE.md` | Why the rules are the way they are — read on demand |
| `docs/workflow.md` | Branching, checks, the sync loop |
| `docs/commands.md` | Cheat sheet for the `.claude/skills/` commands |

---

## Known limitations

- Nothing is built yet. Phase 0 (a shell script proving the mechanism) is active —
  see `docs/ROADMAP.md` "Current status".
- One session at a time, one repo at a time, one user. By design, not by omission.
- macOS only, and `NSStatusItem` means it lives in the menu bar or nowhere.
