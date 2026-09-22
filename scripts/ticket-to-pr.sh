#!/usr/bin/env bash
# ticket-to-pr.sh — Phase 0 mechanism script (docs/ROADMAP.md, Phase 0).
#
# Given a GitHub issue number, create an isolated git worktree and branch of this
# repo, then run a headless Claude Code session inside it with a stripped
# environment and a wall-clock ceiling. Later Phase 0 issues add prompt assembly
# from the issue (#3), the post-session test run and draft PR (#4), and the audit
# record (#5).
#
# Usage:
#   scripts/ticket-to-pr.sh <issue-number> <prompt>
#
# Environment:
#   WORKTREE_PARENT  (optional)  Directory that holds ticket-<n> worktrees.
#                                Default: the path in docs/DESIGN.md §2.
#   ALLOWED_TOOLS    (optional)  Passed through as --allowedTools. Used by the
#                                Phase 0 probe runs that verify the environment
#                                allowlist and the ceiling; a production run sets
#                                nothing and inherits the target repo's own
#                                permission settings.
#   WALL_CLOCK_CEILING_SECONDS, MAX_TURNS  (optional)
#                                Override the ceilings below. They exist so a
#                                probe run can trip a ceiling in under a minute;
#                                Phase 1 reads both from Constants.swift instead.
#
# The target repo is the one this script lives in — the app builds itself first
# (docs/PRD.md §2). Conventions shared with the Phase 1 app (docs/DESIGN.md §2):
# the worktree is "$WORKTREE_PARENT/ticket-<n>", the branch is "ticket-<n>", both
# off the repo's default branch as the remote reports it, and the run log is
# "$WORKTREE_PARENT/../runs/ticket-<n>.jsonl" — outside the worktree, so the
# session cannot edit its own record. Nothing here pushes, merges, or touches the
# default branch. The session's cwd is always the ticket worktree, never this
# checkout (CLAUDE.md §12).
#
# Re-running for the same issue is refused while its worktree or branch exists;
# once those are cleaned up, a new run truncates the previous run log. Durable
# per-run records are issue #5's job, not this file's.

set -euo pipefail

readonly WORKTREE_PARENT_DEFAULT="$HOME/Library/Application Support/ClaudeAssistant/worktrees"

# --- constants (CLAUDE.md §5: no business number lives inline) ---------------

# Wall-clock ceiling, seconds. Starting value from docs/PRD.md §4 ("~20 min").
readonly WALL_CLOCK_CEILING_SECONDS="${WALL_CLOCK_CEILING_SECONDS:-1200}"
# Seconds between SIGTERM and SIGKILL when the ceiling trips.
readonly KILL_GRACE_SECONDS=5
# Turn ceiling, enforced by claude itself via --max-turns.
readonly MAX_TURNS="${MAX_TURNS:-40}"
# Fixed PATH for the child; the directory holding claude is prepended at spawn.
readonly CHILD_PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
# Keychain item holding the API key (docs/DESIGN.md §2).
readonly KEYCHAIN_SERVICE="ClaudeAssistant"
readonly KEYCHAIN_ACCOUNT="anthropic"
# The one permission mode this script will never pass (docs/PRD.md §3 principle 3).
readonly FORBIDDEN_PERMISSION_MODE="bypassPermissions"

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

note() { printf 'ticket-to-pr: %s\n' "$1" >&2; }

# --- inputs -----------------------------------------------------------------

command -v git >/dev/null \
  || die "PATH" "git on PATH" "not found" "install Xcode command-line tools"
command -v jq >/dev/null \
  || die "PATH" "jq on PATH" "not found" "brew install jq"

# A ceiling that isn't a positive integer is a disabled ceiling, which is the one
# thing this script exists to prevent — so it is an error, not a fallback.
[[ "$WALL_CLOCK_CEILING_SECONDS" =~ ^[1-9][0-9]*$ ]] \
  || die "WALL_CLOCK_CEILING_SECONDS" "a positive whole number of seconds" \
         "'$WALL_CLOCK_CEILING_SECONDS'" "unset it to use the default, or pass a positive integer"
[[ "$MAX_TURNS" =~ ^[1-9][0-9]*$ ]] \
  || die "MAX_TURNS" "a positive whole number of turns" "'$MAX_TURNS'" \
         "unset it to use the default, or pass a positive integer"

claude_bin="$(command -v claude || true)"
[[ -n "$claude_bin" ]] \
  || die "PATH" "claude on PATH" "not found" \
         "install Claude Code, or add its directory to PATH before running this"

issue="${1:-}"
[[ "$issue" =~ ^[0-9]+$ ]] \
  || die "argument 1" "a GitHub issue number (digits only)" "'${issue}'" \
         "run as: scripts/ticket-to-pr.sh <issue-number> <prompt>"

prompt="${2:-}"
[[ -n "$prompt" ]] \
  || die "argument 2" "a prompt for the session" "empty" \
         "pass one explicitly for now; assembling it from the issue is issue #3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null)" \
  || die "$script_dir" "this script to live inside a git working tree" \
         "not inside a git repository" "run it from its place in the repo, not a copy"

worktree_parent="${WORKTREE_PARENT:-$WORKTREE_PARENT_DEFAULT}"
branch="ticket-$issue"
worktree_path="$worktree_parent/$branch"
runs_dir="$(dirname "$worktree_parent")/runs"
run_log="$runs_dir/$branch.jsonl"
run_err="$runs_dir/$branch.stderr"

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

# --- permission mode, from the target repo's own settings --------------------
# Never invented here, and bypassPermissions is refused rather than silently
# dropped, so a repo that asks for it gets an answer instead of a surprise.

permission_mode=""
target_settings="$worktree_path/.claude/settings.json"
if [[ -f "$target_settings" ]]; then
  permission_mode="$(jq -r '.permissions.defaultMode // empty' "$target_settings" 2>/dev/null || true)"
fi
if [[ "$permission_mode" == "$FORBIDDEN_PERMISSION_MODE" ]]; then
  die "$target_settings" \
      "any permission mode but $FORBIDDEN_PERMISSION_MODE" \
      "permissions.defaultMode is $FORBIDDEN_PERMISSION_MODE" \
      "this script never passes it (docs/PRD.md §3 principle 3); change the repo's setting"
fi

# --- the child environment: an allowlist, built here and nowhere else ---------
# docs/DESIGN.md §2 is the list. Nothing is inherited implicitly — env -i starts
# from empty and every variable below is named on purpose.

child_path="$(dirname "$claude_bin"):$CHILD_PATH"
child_env=(
  "PATH=$child_path"
  "HOME=$HOME"
  "TMPDIR=${TMPDIR:-/tmp}"
  "LANG=${LANG:-en_US.UTF-8}"
  "USER=${USER:-$(id -un)}"
)

# The API key is the one secret the session gets, and only if it is in Keychain.
# When it is absent, claude falls back to the OAuth login in ~/.claude, which it
# finds via Keychain — but only when USER is set (docs/DESIGN.md §2).
api_key=""
if api_key="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)"; then
  child_env+=("ANTHROPIC_API_KEY=$api_key")
  note "auth: ANTHROPIC_API_KEY from Keychain ($KEYCHAIN_SERVICE/$KEYCHAIN_ACCOUNT)"
else
  api_key=""
  note "auth: no Keychain item $KEYCHAIN_SERVICE/$KEYCHAIN_ACCOUNT — using the OAuth login in \$HOME"
fi

# --- spawn -------------------------------------------------------------------

claude_args=(
  -p "$prompt"
  --output-format stream-json
  --verbose                      # required by claude with --print + stream-json
  --max-turns "$MAX_TURNS"
)
if [[ -n "$permission_mode" ]]; then
  claude_args+=(--permission-mode "$permission_mode")
fi
if [[ -n "${ALLOWED_TOOLS:-}" ]]; then
  claude_args+=(--allowedTools "$ALLOWED_TOOLS")
fi

mkdir -p "$runs_dir"
: > "$run_log"
: > "$run_err"

printf 'run log:  %s\n' "$run_log"
printf 'ceiling:  %ss wall clock, %s turns\n' "$WALL_CLOCK_CEILING_SECONDS" "$MAX_TURNS"

# Job control gives the child its own process group, with pgid == pid. The
# ceiling kills the group, not the pid, so a test runner the session spawned
# dies with it (docs/DESIGN.md §7, "runaway session survives the ceiling").
set -m
(
  cd "$worktree_path"
  exec env -i "${child_env[@]}" "$claude_bin" "${claude_args[@]}"
) > "$run_log" 2> "$run_err" &
child_pid=$!
set +m

started="$SECONDS"
outcome=""
while kill -0 "$child_pid" 2>/dev/null; do
  if (( SECONDS - started >= WALL_CLOCK_CEILING_SECONDS )); then
    outcome="ceiling_wall_clock"
    note "wall-clock ceiling reached after $((SECONDS - started))s — killing process group $child_pid"
    kill -TERM -"$child_pid" 2>/dev/null || true
    grace_until=$(( SECONDS + KILL_GRACE_SECONDS ))
    while kill -0 "$child_pid" 2>/dev/null && (( SECONDS < grace_until )); do sleep 1; done
    kill -KILL -"$child_pid" 2>/dev/null || true
    break
  fi
  sleep 1
done

exit_code=0
wait "$child_pid" 2>/dev/null || exit_code=$?
elapsed=$(( SECONDS - started ))

# --- exit reason: from what this script observed, never from session output ---
# docs/DESIGN.md §3. The only inputs are our own timer, claude's exit code, and
# the machine-readable fields of the result line — never its prose.

total_lines="$(awk 'END { print NR + 0 }' "$run_log")"
valid_lines="$(jq -R 'fromjson? | 1' "$run_log" 2>/dev/null | wc -l | tr -d ' ')"
malformed=$(( total_lines - valid_lines ))
result_json="$(jq -c -R 'fromjson? | select(.type == "result")' "$run_log" 2>/dev/null | tail -1)"

subtype=""
is_error=""
num_turns=""
if [[ -n "$result_json" ]]; then
  subtype="$(printf '%s' "$result_json" | jq -r '.subtype // empty')"
  is_error="$(printf '%s' "$result_json" | jq -r '.is_error // empty')"
  num_turns="$(printf '%s' "$result_json" | jq -r '.num_turns // empty')"
fi

if [[ -z "$outcome" ]]; then
  if [[ -z "$result_json" ]]; then
    # Claude exited without ever emitting a result line: an auth failure, a
    # crash, or a kill from outside. Nothing here can tell those apart yet.
    outcome="task_failure"
  elif [[ "$subtype" == "error_max_turns" ]]; then
    outcome="ceiling_max_turns"
  elif [[ "$is_error" == "true" ]]; then
    # Observed on 2.1.273: subtype stays "success" while is_error is true, so
    # is_error is the authority and subtype alone would silently mislabel.
    outcome="task_failure"
  elif [[ "$subtype" == "success" ]]; then
    if (( exit_code != 0 )); then
      outcome="task_failure"
    else
      outcome="completed"
    fi
  else
    # docs/DESIGN.md §3: an unrecognized subtype is recorded verbatim, so the
    # finding is paste-able rather than defaulted away.
    outcome="unknown:$subtype"
  fi
fi

printf 'exit reason: %s\n' "$outcome"
printf 'exit code:   %s\n' "$exit_code"
printf 'elapsed:     %ss (ceiling %ss)\n' "$elapsed" "$WALL_CLOCK_CEILING_SECONDS"
printf 'turns:       %s (max %s)\n' "${num_turns:-unknown}" "$MAX_TURNS"
printf 'stream:      %s lines, %s malformed\n' "$total_lines" "$malformed"
if [[ -s "$run_err" ]]; then
  printf 'stderr:      %s\n' "$run_err"
fi

[[ "$outcome" == "completed" ]] || exit 1
