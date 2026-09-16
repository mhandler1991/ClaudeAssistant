---
description: Check this project's doc set and skills against the project-kickoff standard — duplicated facts, root/docs drift, stale roadmap vs. milestones, missing done-when bars, gates with no trigger
argument-hint: [optional — focus area, e.g. "just the workflow ritual"]
allowed-tools: Read, Grep, Glob, Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh api repos/mhandler1991/ClaudeAssistant/milestones*), Bash(gh repo view:*)
---

# Doc set audit

$ARGUMENTS

(If empty, audit the whole doc set. If given, narrow to what was named, but still
flag anything else that's clearly broken.)

## What to check

1. **Duplicated facts.** The same specific claim in more than one file — not similar
   topics, the same fact. Report the files and the fact, and say which should own it.
2. **Root vs. `docs/` drift.** Only `README.md`, `CLAUDE.md`, and `LICENSE` belong at
   repo root.
3. **`CLAUDE.md` restating instead of routing.** Any paragraph duplicating
   `docs/workflow.md`, `docs/DESIGN.md`, or `.github/PULL_REQUEST_TEMPLATE.md` should
   be a pointer.
4. **Doc-vs-complexity mismatch.** A doc that exists without earning it, or a missing
   one the project has grown into (a `DATA-MODEL.md` once the audit record is read
   cross-run, per `docs/DESIGN.md` §2).
5. **`ROADMAP.md` vs. GitHub milestones.** Compare phase `**Milestone:**` names against
   `gh api repos/mhandler1991/ClaudeAssistant/milestones?state=all` — flag any phase
   without a milestone, or milestone without a phase.
6. **Missing structural pieces.** No "done when" bar on a phase, no principles section
   in `docs/PRD.md`, no doc map in `CLAUDE.md` §0.
7. **Skills without `disable-model-invocation`.** Any `.claude/skills/*/SKILL.md` with a
   side effect (branches, pushes, deletes, files an issue, opens a PR) not set to
   `disable-model-invocation: true`.
8. **Un-probed argument indexing.** Any skill using `$0`/`$1`/`$ARGUMENTS` — confirm it
   matches this installation's actual behavior (`.claude/skills/probe-args/` exists
   until that's been done once; its continued existence is itself a finding).
9. **A documented gate with no forced trigger.** A step described in `CLAUDE.md` or
   `docs/workflow.md` that lives in a command separate from the one that always runs.
   Cross-check against evidence: do closed issues actually carry a `## Shipped in`
   comment?
10. **A cleanup step that's a silent no-op.** Check `gh repo view --json
    deleteBranchOnMerge` — if false, `/merged`'s prune has never done anything.
11. **A record-writing step that isn't idempotent.** Anything posting a comment or
    label that doesn't check for its own prior output first.
12. **A compound (`&&`) or piped (`|`) command anywhere in a skill**, injected or not.
13. **Reliance on an API/CLI field's name instead of its verified behavior** — a
    "closing references"-style field instead of the `closes #N` text.
14. **Reconstructed reasoning presented as recalled fact**, especially in a command
    that might run cold.
15. **Command-set drift.** Does `docs/commands.md` list every skill in
    `.claude/skills/` and nothing removed? Does `CLAUDE.md` §11 match?
16. **A `.claude/skills/ship/` directory existing at all** — an error, not a style note
    (`docs/RATIONALE.md` R1, R5).
17. **Paragraph-length justification inline in `start` or `merged`** that should be a
    pointer into `docs/RATIONALE.md`.
18. **A missing or stale audit log.** Is there an `audit-log`-labeled issue? Does its
    comment count roughly track merged PRs, or are there merged cycles with no
    `## Cycle #{PR}` entry?
19. **Unreviewed `kit candidate` findings** in the audit log — report the count.
20. **`docs/DESIGN.md` §2–§3 vs. Phase 0 reality.** Once `scripts/ticket-to-pr.sh` has
    run, does the env allowlist and `claude -p` invocation recorded there match what
    the script actually does? Those sections were written as a plan, and say so.

## Report

Concretely — file and what's wrong, not "improve documentation". Then ask whether to
fix what was found rather than fixing it unprompted; #4 in particular is a judgment
call the developer may see differently.
