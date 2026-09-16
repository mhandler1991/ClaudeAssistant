# ClaudeAssistant — branching, checks and sync workflow

> The developer ↔ Claude loop: how code moves from a feature branch → `dev` → `main`,
> what's automated, and exactly what to tell Claude at each step.

Legend: ⚡ Claude does this · 👤 you do this · 🚫 never · 📌 in scope now · 🔮 deferred

---

## 1. The big picture

```
main   ── production (tagged; what you actually run day to day)
  ▲
  │  PR (dev → main) + tag           👤 you merge and tag, ⚡ /promote opens it
  │
dev    ── integration
  ▲
  │  PR (feature → dev)              ⚡ /start opens · 👤 you merge
  │
feature/<issue>-<slug>
```

🚫 Never commit or push directly to `dev` or `main`. Everything goes through a branch
and a PR.

📌 **`dev` is the repository's default branch, deliberately** — GitHub auto-closes an
issue only when a PR merges into the default branch, and every feature PR targets
`dev`.

"Production" here means the build you run from `main` on your own machine. There's no
deploy target — `/promote` + a tag is the whole release.

---

## 2. Automated vs. manual

| Thing | Status | Notes |
|---|---|---|
| `swift build` / `swift format lint` / `swift test` | ⚡ `/start` runs them locally before every PR | No CI workflow yet — there's nothing to build until `Package.swift` exists. Add a GitHub Actions workflow in the same PR that adds `Package.swift`; from then on it blocks merge |
| `bash -n scripts/*.sh` | ⚡ `/start`, Phase 0 | The only automated check while Phase 0 is active |
| The ticket-to-PR loop itself, against a real `Rogue-Arcade` issue | 👤 Manual | Needs a real `claude` session and real GitHub state; faking either tests nothing that matters (`ROADMAP.md` "How to iterate") |
| Menu-bar smoke test (launches, status item appears, Idle renders) | 👤 Manual | Until Phase 2's Diagnostics tab gives a test something to read |

---

## 3. Standard feature loop

**Two commands, not three.** `/start` runs end-to-end through "PR is open": implement,
self-review against acceptance criteria, prohibition sweep, checks with real output
reported, commit with actual reasoning in the body, push, open the PR. There is no
separate ship step (why: `RATIONALE.md` R1).

| # | Step | Who | Say this |
|---|---|---|---|
| 1 | Start (implement through PR) | 👤→⚡ | `/start {issue}` |
| 2 | Merge | 👤 | — |
| 3 | Sync | 👤→⚡ | `/merged {pr}` |
| 4 | Test | 👤 | — |

**This table is the single source of truth for the loop.** `commands.md` cross-links
here rather than reproducing it.

📌 **Workflow intensity.** This project runs `solo-trusted` (`CLAUDE.md` §3): `/start`
bundles small related issues into one session by default, and `/batch-issues` exists.
Neither touches step 2 — merge is a human, on every PR.

📌 **Repo setup requirement:** `/merged`'s branch cleanup only has an effect if
`delete-branch-on-merge` is enabled on the repo (`gh repo edit
--delete-branch-on-merge`, done once at setup). Without it, the prune step runs clean
and deletes nothing, indefinitely, without ever signaling that anything's wrong.

📌 One session per issue (or small coupled cluster) — `/start` re-derives everything it
needs from `gh`/`git`, so a fresh session costs nothing but the fixed context reload.

📌 Anything more than a couple of prompts to implement and verify gets its own issue —
use `/new-issue` to file it in the right shape rather than a bare title.

---

## 4. Promote to production

Say **"promote dev → main"**, or run `/promote`. It opens the `dev → main` PR; you
merge it and tag the release (`v0.{phase}.{patch}` — `v0.1.0` is the first Phase 1
promotion). Tags are the rollback handle — don't skip them.

---

## 5. Testing before you promote

Run the app from `dev` for at least one real ticket before promoting. The automated
checks prove it compiles and the units hold; they can't prove the loop works against
GitHub and `claude`, and that's the thing being promoted.

---

## 6. Gotchas

None hit yet. This section fills in from the audit log as real ones land — state what
it *looks like* when it happens, so it's findable by search later.

---

## 7. Issues, milestones, branch naming

📌 **The audit log.** `/merged` posts to the project's `audit-log`-labeled issue every
cycle — most findings there govern this project; some are tagged `kit candidate` and
apply to `project-kickoff` itself, reviewed separately and manually. Read the issue's
own body for the exact format.

**Milestones** are one per phase, named exactly as each phase's `**Milestone:**`
line in `ROADMAP.md` names them. `ROADMAP.md` is the source;
milestones follow it, never the reverse.

**Labels:** `owner:claude` (Claude implements), `owner:you` (a setting, a real-run
test, a judgement call), `blocked`, `audit-log`. The `ready` / `in-progress` labels
belong to the *target* repo (`Rogue-Arcade`), not this one.

**Branch naming:** `feature/{issue}-{slug}` — `feature/12-env-allowlist`. No issue:
`feature/{slug}`.

📌 **"Current phase"**, wherever it's referenced here or in `.claude/skills/`, means
whatever `ROADMAP.md`'s "Current status" section names as active — that section is the
source of truth, not a value to guess or carry over from an earlier conversation.

---

## 8. What to tell Claude

| Moment | Say this |
|---|---|
| Starting (through PR) | `/start {issue}` — append anything broken or delicate |
| Starting several small related issues together | `/start {issue} {issue} ...` |
| Starting, no issue | "Branch off `dev` for `<thing>`, no issue" |
| New work discovered | `/new-issue {description}` |
| Working a batch unattended | `/batch-issues {milestone or issue list}` |
| After merging | `/merged {pr}` |
| Releasing | `/promote`, or say "promote dev → main" |
| Checking the doc set | `/audit-docs` |
| "What commands do I have?" | `/commands` |

---

## 9. When something breaks in a way that resists explanation

This project is *made of* process boundaries, timeouts, and a child that may or may
not exit — the class of bug that resists explanation is the expected class, not the
exception. When one shows up: stop explaining, write an isolation test (a fake
`Process` that never exits; a transcript fixture with the exact malformed line),
instrument the actual distinction that matters under the `signal` or `action` log
category, and say plainly whether the fix was *observed* working or *inferred* — the
same rule `ROADMAP.md` "How to iterate" sets for the loop itself.
