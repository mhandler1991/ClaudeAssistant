---
description: Start work on one or more GitHub issues — loads them, branches, implements, self-reviews, and opens the PR
argument-hint: [issue-number ...] [anything broken or delicate]
disable-model-invocation: true
allowed-tools: Bash(gh issue view:*), Bash(gh issue create:*), Bash(git log:*), Bash(git status:*), Bash(git branch:*), Bash(git fetch:*), Bash(git checkout:*), Bash(git pull:*), Bash(git push:*), Bash(git add:*), Bash(git commit:*), Bash(gh pr create:*), Bash(swift build:*), Bash(swift format lint:*), Bash(swift test:*), Bash(bash -n:*)
---

# Start issue #$0

## The first issue

!`gh issue view $0`

## Repo state

- Fetch latest: !`git fetch origin dev --quiet`
- Latest on dev: !`git log --oneline -5 origin/dev`
- Working tree: !`git status --short`
- Current branch: !`git branch --show-current`
- Does the feature branch already exist: !`git branch --list feature/$0-*`

(Five separate single-command injections — no `&&` or `|` anywhere in this file.)

## Additional issues, if any

$ARGUMENTS is the full argument string, including the leading `$0`. If it contains
more than one leading numeric token, every one beyond `$0` is another issue to work in
this same session — fetch each with its own `gh issue view` call, issued together in
one turn. The first non-numeric token ends the issue list; everything after it is
free-text context.

**Only bundle issues that are actually small and closely related.** Verify that
judgment holds once you're looking at the issues, and say so plainly (one-line reason)
if you're splitting them back into separate sessions.

## What you flagged

$ARGUMENTS

(Leading numeric tokens are the issue number(s); everything after them is context
about what's broken, delicate, or recently changed. Nothing after them means nothing
to flag.)

## How to run this session

1. Read every issue above first — each one's acceptance criteria are its own
   definition of done. Bundled issues don't share criteria.
2. **Check the working tree before doing anything else.** Uncommitted changes shown
   above are from a prior session — don't silently build on them. Ask whether to
   stash, discard, or continue, unless it's obviously unrelated leftover output.
3. Read `docs/PRD.md` and `docs/ROADMAP.md`. Read `docs/DESIGN.md` **only if** the
   work touches `Session/`, `Worktree/`, `Audit/`, `State/`, or `scripts/` (the
   `CLAUDE.md` §0 rule).
4. Look up current docs (Context7) for any Apple or Swift Testing API this touches
   that you're not certain about.
5. **Branch off `dev`, named for the first issue with a short kebab-case slug from its
   title — or resume if that branch already exists.** If "Does the feature branch
   already exist" above returned a match:
   ```bash
   git checkout feature/$0-<slug>
   ```
   Otherwise, as four separate commands:
   ```bash
   git checkout dev
   ```
   ```bash
   git pull origin dev
   ```
   ```bash
   git checkout -b feature/$0-<slug>
   ```
   ```bash
   git push -u origin feature/$0-<slug>
   ```
6. Implement — everything bundled into this session, on this one branch.
7. **Self-review against every issue's acceptance criteria separately**, item by item.
   Anything not met on any one of them, say so plainly.
8. **Small, closely-related discovered work:** this project is `solo-trusted`
   (`CLAUDE.md` §3) — file it via `gh issue create` in the `/new-issue` shape right
   now so it has real acceptance criteria, then fold it into *this* session's scope.
   Never leave discovered work as an unfiled note.
9. **Run the prohibition sweep** from `CLAUDE.md` §2 and §12: no merge / force-push /
   default-branch-write code path; no child `Process` outside the `Session/` wrapper;
   no inherited environment passed to a child; no hardcoded ceilings or label names;
   no `print()` outside `scripts/`; no `TODO` without an issue number; no
   `@unchecked Sendable` without a justifying comment; no secrets; no commented-out
   code.
10. **Run the checks and report the real output — as separate commands, not chained.**
    If `Package.swift` doesn't exist yet (Phase 0), only the last one applies:
    ```bash
    swift build
    ```
    ```bash
    swift format lint --recursive Sources Tests
    ```
    ```bash
    swift test
    ```
    ```bash
    bash -n scripts/ticket-to-pr.sh
    ```
    If anything fails, fix the implementation. 🚫 Never change a test to make it pass.
11. **Stage specific files** — 🚫 never a blanket add — and commit with a real body:
    ```
    type(scope): description

    What changed, in a sentence or two.

    Decisions: key calls made and alternatives rejected — this is what GitHub seeds
    into the PR body, which /merged reads later to build the completion record.

    — closes #$0, closes #<each additional issue if bundled>
    ```
12. **Push**, then open a PR **into `dev`** using `.github/PULL_REQUEST_TEMPLATE.md`.
    Title names every bundled issue. The body must contain a `Closes #N` line for
    **every** issue this session worked.
13. **Report the PR URL and anything you could not verify**, per issue if bundled.

Throughout: state assumptions inline rather than asking. Ask one question, and only
when the answer would change what gets built.
