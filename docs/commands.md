# Commands — cheat sheet

> Source: [`.claude/skills/`](../.claude/skills/). Full mechanics in
> [`workflow.md`](workflow.md) §3 · standards in [`../CLAUDE.md`](../CLAUDE.md).
>
> These are Claude Code **skills**, not the older `.claude/commands/` files — same
> `/name` invocation, but every one below with a side effect is set to
> `disable-model-invocation: true`, so Claude runs it only when you type it.

---

## The loop

```
/start {issue}  →  implement, self-review, sweep, checks, commit, PR  →  👤 merge  →  /merged {pr}  →  👤 test
```

⚠️ **`/merged` takes the PR number. `/start` and `/new-issue` take the issue number or
a description.** Different things; easiest mistake to make.

---

## `/start {issue} [{issue} ...] [anything broken]`

**Injects:** first issue's body · recent commits on `dev` · working tree · current
branch · whether the feature branch already exists.
**Then:** reads `PRD.md` and `ROADMAP.md`, plus `DESIGN.md` only if the work touches
`Session/`, `Worktree/`, `Audit/`, `State/`, or `scripts/` · branches
`feature/{issue}-{slug}` (named for the first issue, resuming if that branch already
exists) · implements · self-reviews each issue's acceptance criteria separately · runs
the prohibition sweep from `CLAUDE.md` §2/§12 · runs the checks in `workflow.md` §2
and reports the real output · commits with real reasoning in the body · pushes · opens the PR into `dev`,
`Closes #N` for every issue involved.

More than one issue number bundles them into one session and one PR — only when
they're genuinely small and closely related; the command will say so and split back
apart if they turn out not to be. The trailing text after the last issue number is
the only thing it can't derive on its own — say what's broken or delicate there.

## `/merged {pr}`

Verifies the PR is actually merged via the GitHub API (not local git state), syncs
`dev`, force-deletes the confirmed branch using its real `headRefName`, confirms the
issue closed by reading the actual `closes #N` text, files any follow-ups *before*
citing their numbers, posts an idempotent completion record on the issue, and posts
one entry to the audit-log issue — every cycle, including "No findings".

**Do not skip this** — it's the one step that looks optional and isn't.

## `/promote`

Opens the `dev → main` PR. You merge it and tag the release yourself — tagging isn't
automated on purpose, since it's the rollback handle.

## `/new-issue {description}`

Turns a rough description into a properly formatted GitHub issue: title, acceptance
criteria, milestone, `owner:` label. Use this instead of hand-typing an issue whenever
something crosses the "more than a couple prompts" threshold — this one has no forced
trigger the way `/start` does, so it only works if it's actually used.

## `/batch-issues {milestone or issue list} [batch-size]`

Works several eligible issues back-to-back without a check-in between them, up to
the ceiling in `CLAUDE.md` §3 — each still gets its own branch, its own PR, and its own required human
merge. Eligibility is checked twice: before implementing (clear acceptance criteria,
`owner:claude`, not the first issue of a phase, doesn't touch `Session/`'s env
allowlist or `Audit/`) and after (checks green, diff size reasonable for what the
issue described) — a flagged issue still gets a PR, just marked for a closer look, and
stops the batch there. Exists because this project's workflow intensity is
`solo-trusted` (`CLAUDE.md` §3).

## `/audit-docs`

Checks the doc set and the `.claude/skills/` commands themselves for the failure modes
the kickoff kit is built to avoid: duplicated facts across files, root/`docs` drift,
`ROADMAP.md` phases vs. real milestones, a documented gate with no forced trigger, a
cleanup step that's a silent no-op, a record-writing step that isn't idempotent, a
compound or piped command in a skill, and more. Read-only — reports, doesn't auto-fix
unless you ask it to.

## `/commands`

Lists this project's own `.claude/skills/` commands and what they do — this file,
live. For Claude Code's built-in commands, run `/help`; for every installed skill
including bundled ones, run `/skills`.

---

## What stays manual

| Step | Why |
|---|---|
| Merging any PR | You review, you merge |
| Tagging a release | The rollback handle — deliberately not automated |
| Running the loop against a real `Rogue-Arcade` issue | Needs a live `claude` session and real GitHub state; the success bar is about real PRs |
| Menu-bar smoke test | No automated hook into the status item until Phase 2 |
| Putting the API key in Keychain | Once, by hand — the app reads it, never writes it |

---

## Working without an issue

`Branch off dev for <thing>, no issue` — for spikes/alignment passes. Branch naming
drops the number: `feature/{slug}`.

---

## Fixing a command

They're markdown files in `.claude/skills/<name>/SKILL.md`, version controlled like
anything else. Fix a wrong ritual in a PR, not in muscle memory. If you change how
positional arguments behave, or how any tool/API field behaves, confirm the new
behavior with a real, throwaway test before trusting a fix built on it.
