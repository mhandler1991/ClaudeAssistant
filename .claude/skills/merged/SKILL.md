---
description: Sync after a PR merge — verify via API, clean up the branch, post an idempotent completion record and an audit-log entry
argument-hint: [pr-number]
disable-model-invocation: true
allowed-tools: Bash(gh pr view:*), Bash(gh issue view:*), Bash(gh issue create:*), Bash(git checkout:*), Bash(git pull:*), Bash(git branch:*), Bash(git remote prune:*), Bash(git status:*), Bash(gh issue comment:*), Bash(gh issue list:*)
---

# Merged #$ARGUMENTS

## PR state and reasoning material

!`gh pr view $ARGUMENTS --json state,headRefName,baseRefName,mergedAt,title,body,commits,files`

(One call, not a pipeline. The issue's own comments are fetched in step 8, once the
issue number is known.)

## Sequence

1. **Confirm the PR is `state: MERGED`** in the JSON above before touching anything.
   If it isn't, stop and report — no branch deletion, no completion record.

2. **Sync `dev`**, as two separate commands:
   ```bash
   git checkout dev
   ```
   ```bash
   git pull origin dev
   ```

3. **Delete the feature branch with `-D`, using the exact `headRefName` from the JSON
   above** — not `-d`, not a reconstructed name. (Why `-D` is correct here:
   `docs/RATIONALE.md` R2.)

4. **Prune stale remote-tracking refs**, as two separate commands:
   ```bash
   git remote prune origin
   ```
   ```bash
   git status --short
   ```
   If `delete-branch-on-merge` is off at the repo level this is a permanent no-op —
   say so rather than reporting "cleaned up" when nothing was cleaned.

5. **Determine which issue this closes** by reading `closes #N` (or `fixes`/`resolves`)
   out of the injected title, body, and commit messages — never from a
   `closingIssuesReferences`-style field (why: `docs/RATIONALE.md` R3). If they
   disagree, ask rather than guess. If the PR names more than one issue, the
   first-listed is primary for the record in step 8; name the others inside that same
   record.

6. **Confirm the issue actually closed.** If it's still open, say so rather than
   assuming `Closes #N` fired.

7. **File every follow-up before writing anything that cites its number.** Run
   `gh issue create` for each one now and capture the real numbers `gh` returns.
   (Why: `docs/RATIONALE.md` R4.)

8. **Post the completion record — idempotently, on the issue, not the PR.**
   ```bash
   gh issue view <issue-number> --json comments
   ```
   Check for an existing comment starting with `## Shipped in #$ARGUMENTS`. If one
   exists, don't post another. Otherwise post exactly this shape, built from the PR
   body/commits/files injected above and the real issue numbers from step 7:
   ```bash
   gh issue comment <issue-number> --body "..."
   ```

   ```markdown
   ## Shipped in #$ARGUMENTS

   **What:** one or two sentences

   **Decisions and what was rejected:** pulled from the commit body `/start` wrote

   **Verified:** the actual command run and its actual result, per acceptance
   criterion — not the criteria restated as if self-evidently met

   **Deliberately not done:** scope explicitly left out, if any

   **Follow-ups:** the real issue numbers from step 7, linked
   ```

   **If this session did not do the build**, say so plainly in the record instead of
   presenting reconstructed reasoning as recalled fact.

9. **Evaluate this cycle for the audit log — every cycle, including ones with nothing
   to report.** Find the log by label, not number:
   ```bash
   gh issue list --label audit-log --state open --json number,comments
   ```
   Check the returned comments for an existing `## Cycle #$ARGUMENTS` entry first.
   Then evaluate this cycle against the issue's own two-part test (transferable +
   evidenced). If nothing qualifies, post "No findings" — the expected outcome. Post
   with:
   ```bash
   gh issue comment <audit-log-issue-number> --body "..."
   ```

10. **Report what's next.** "Current phase" means whatever `docs/ROADMAP.md`'s
    "Current status" section names as active — read it, don't reuse a stale value:
    ```bash
    gh issue list --milestone "<current phase milestone>" --state open
    ```
