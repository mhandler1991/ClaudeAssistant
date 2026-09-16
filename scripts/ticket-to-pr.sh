#!/usr/bin/env bash
# ticket-to-pr.sh — Phase 0 mechanism script (docs/ROADMAP.md, Phase 0).
#
# Given a GitHub issue number, create an isolated git worktree and branch of this
# repo for a headless Claude Code session to run in. This is the skeleton; later
# Phase 0 issues add the session spawn, prompt assembly, tests, and PR.
#
# Usage:
#   scripts/ticket-to-pr.sh <issue-number>
#
# Environment:
#   WORKTREE_PARENT  (optional)  Directory that holds ticket-<n> worktrees.
#                                Default: the path in docs/DESIGN.md §2.
#
# The target repo is the one this script lives in — the app builds itself first
# (docs/PRD.md §2). Conventions shared with the Phase 1 app (docs/DESIGN.md §2):
# the worktree is "$WORKTREE_PARENT/ticket-<n>", the branch is "ticket-<n>", both
# off the repo's default branch as the remote reports it. Nothing here pushes,
# merges, or touches the default branch. The session's cwd is always the ticket
# worktree, never this checkout (CLAUDE.md §12).

set -euo pipefail

readonly WORKTREE_PARENT_DEFAULT="$HOME/Library/Application Support/ClaudeAssistant/worktrees"

# Every error is shaped to be pasted straight back into a Claude session:
# where it happened, what was expected, what was actually found, and a fix.
die() {
  local where="$1" expected="$2" actual="$3" fix="$4"
  printf 'ticket-to-pr: refusing to continue\n' >&2
  printf '  where:    %s\n' "$where" >&2
  printf '  expected: %s\n' "$expected" >&2
  printf '  actual:   %s\n' "$actual" >&2
  printf '  fix:      %s\n' "$fix" >&2
  exit 1
}

# --- inputs -----------------------------------------------------------------

command -v git >/dev/null \
  || die "PATH" "git on PATH" "not found" "install Xcode command-line tools"

issue="${1:-}"
[[ "$issue" =~ ^[0-9]+$ ]] \
  || die "argument 1" "a GitHub issue number (digits only)" "'${issue}'" \
         "run as: scripts/ticket-to-pr.sh <issue-number>"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$script_dir" "this script to live inside a git working tree" \
         "not inside a git repository" "run it from its place in the repo, not a copy"

worktree_parent="${WORKTREE_PARENT:-$WORKTREE_PARENT_DEFAULT}"
branch="ticket-$issue"
worktree_path="$worktree_parent/$branch"

# --- default branch, as the remote reports it --------------------------------
# Local origin/HEAD is only set by clone; a repo whose remote was added later has
# none (this one, for instance). Try local first, then ask the remote — read-only.

default_branch=""
if ref="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"; then
  default_branch="${ref#origin/}"
else
  # First line is "ref: refs/heads/<name>\tHEAD"; cut at the first tab.
  symref="$(git -C "$repo" ls-remote --symref origin HEAD 2>/dev/null || true)"
  symref="${symref%%$'\t'*}"
  symref="${symref#ref: }"
  default_branch="${symref#refs/heads/}"
fi
[[ -n "$default_branch" ]] \
  || die "$repo" "a default branch reported by origin" "none found" \
         "check 'git -C $repo remote -v' and that the remote is reachable"

# --- refuse to reuse anything ------------------------------------------------

[[ ! -e "$worktree_path" ]] \
  || die "$worktree_path" "no file or directory at this path" "already exists" \
         "remove it, or run: git -C $repo worktree remove $worktree_path"

if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
  die "$repo" "no local branch named $branch" "branch exists" \
      "delete it if abandoned: git -C $repo branch -D $branch"
fi

while IFS= read -r line; do
  [[ "$line" == "worktree $worktree_path" ]] \
    && die "$repo" "no registered worktree at $worktree_path" "one is registered" \
           "run: git -C $repo worktree prune (if the directory is gone) or worktree remove"
done < <(git -C "$repo" worktree list --porcelain)

# --- create ------------------------------------------------------------------

git -C "$repo" fetch origin "$default_branch" --quiet
mkdir -p "$worktree_parent"
git -C "$repo" worktree add --quiet -b "$branch" "$worktree_path" "origin/$default_branch"

printf 'worktree: %s\n' "$worktree_path"
printf 'branch:   %s (off origin/%s)\n' "$branch" "$default_branch"
