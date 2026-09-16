---
description: Turn a rough description into a properly formatted GitHub issue (milestone, owner label, acceptance criteria)
argument-hint: [description of the work]
disable-model-invocation: true
allowed-tools: Bash(gh issue create:*), Bash(gh issue list:*), Bash(gh api --method GET repos/mhandler1991/ClaudeAssistant/milestones:*)
---

# New issue: $ARGUMENTS

## Context

- Open milestones (JSON — read the `title` fields): !`gh api --method GET repos/mhandler1991/ClaudeAssistant/milestones -f state=open`
- `docs/ROADMAP.md`'s current phase — read the file directly.

## Sequence

1. **Turn the description into a title and acceptance criteria** using
   `.github/ISSUE_TEMPLATE/feature.md`'s shape (or `bug.md` if this is clearly a bug).
   Acceptance criteria must be concrete enough for `/start`'s self-review to check
   against — specific, checkable conditions, not "make it work".
2. **Match it to a milestone** from `docs/ROADMAP.md`'s phases. If it doesn't cleanly
   fit one, say so rather than forcing it — that's a signal about the roadmap, not
   just this issue.
3. **Assign the owner label**: `owner:claude` if Claude implements it, `owner:you` if
   it's a setting, a real-run test against `Rogue-Arcade`, or a judgement call.
4. **Create it:**
   ```bash
   gh issue create --title "<title>" --milestone "<milestone>" --label "<owner label>" --body "<body in the template shape>"
   ```
5. **Report the issue number and confirm the milestone/label landed.**

If the description clearly describes more than one unit of work, say so and propose
splitting it — the "more than a couple of prompts" threshold in `CLAUDE.md` §3 is
per-issue, not per-request.
