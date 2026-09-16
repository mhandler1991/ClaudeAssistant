---
description: Work through several eligible issues back-to-back, without a check-in between them, up to a batch ceiling — merge still stays manual for every PR
argument-hint: [milestone or issue list] [batch-size override]
disable-model-invocation: true
allowed-tools: Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh issue create:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git fetch:*), Bash(git checkout:*), Bash(git pull:*), Bash(git push:*), Bash(git add:*), Bash(git commit:*), Bash(gh pr create:*), Bash(swift build:*), Bash(swift format lint:*), Bash(swift test:*), Bash(bash -n:*)
---

# Batch issues: $ARGUMENTS

## Candidate issues

If `$ARGUMENTS` names a milestone, list its open issues; if it lists issue numbers, use
those; if empty, use `docs/ROADMAP.md`'s "Current status" section to find the active
phase's milestone:

```bash
gh issue list --milestone "<resolved milestone name>" --state open --json number,title,labels,body
```

## Batch ceiling

Default 3 issues per run; a trailing numeric argument overrides it. Stop at the
ceiling even if more candidates are eligible (why: `docs/RATIONALE.md` R8).

## Eligibility — checked in two stages

**Before implementing anything**, filter candidates to ones where all of these hold:

- Concrete, unambiguous acceptance criteria — no open design question in the body
- Labeled `owner:claude`, not `blocked`
- Not the first issue of its phase
- Doesn't, per its own description, touch the child-environment allowlist in
  `Session/`, the audit writer in `Audit/`, or `scripts/ticket-to-pr.sh`'s env
  stripping (why: `docs/RATIONALE.md` R9)

Report which candidates were excluded and why, one line each, before starting.

**After implementing each one** (following `.claude/skills/start/SKILL.md`'s sequence
in full for that single issue), check the actual diff before opening its PR:

- Checks fully green
- Diff size reasonable for what the issue described — use judgment, and say what you
  used it on

If either fails, still open the PR, but title and flag it as needing a closer look,
and stop the batch there.

## Sequence

For each eligible issue, up to the ceiling:

1. Follow `.claude/skills/start/SKILL.md`'s sequence for this one issue — its own
   branch and PR, not bundled with the others in this loop.
2. Apply the post-implementation check above before opening the PR.
3. Move to the next eligible issue only after this one's PR is open.

**Merge stays manual for every PR this produces.** `/batch-issues` never merges and
doesn't wait for one; run `/merged` on each once you've reviewed and merged it.

## Report

One line per issue worked: number, whether it passed both stages cleanly or got
flagged, and the PR link. One line per excluded candidate and why. Say plainly if the
batch stopped early.
