# Rationale — ClaudeAssistant

> Why things are the way they are, kept separate from the skill files that state what
> to do — those get read every session; this gets read when someone's asking why.

Numbered sequentially. New entries append; nothing gets renumbered or reworded after
the fact. R1–R8 are the kickoff kit's founding rationale; project-specific entries
start at R9.

---

### R1. Why there's no standalone `ship` skill
A step is only a real gate if it sits on a command with no separate invocation to
forget. A separate `/ship` held the only prohibition sweep and completion-comment step
in an earlier version of this kind of project, and it was never reliably invoked on
its own — issues shipped with zero comments because the step that should have written
one lived in a command nobody ran. `/start` now runs end-to-end through the opened PR
instead. `docs/commands.md` and `/audit-docs` both treat a `.claude/skills/ship/`
directory existing at all as an error, not a style choice — see R5 for why keeping it
around "for the reasoning" doesn't actually avoid the cost it was meant to avoid.

### R2. Why `/merged` force-deletes the feature branch with `-D`
It's safe specifically because `/merged` confirms via the GitHub API that the PR is
`MERGED` before deleting anything — not because of git's local ancestry check, which
`-d` relies on and `-D` bypasses. Once a repo squash-merges with `delete-branch-on-merge`
enabled, the local branch tip is never an ancestor of the integration branch, so a
plain `-d` fails on *every* merge and stops being a signal of anything. The API
confirmation is the real safety gate; `-D` after that confirmation is correct, not
reckless.

### R3. Why `/merged` reads "closes #N" from text instead of a structured API field
A "closing references"-style field has been observed returning empty even when the
issue closed correctly — closure is driven by the PR body text GitHub actually parses,
not a separately-tracked relationship that field claims to represent. Trusting the
field's name over its observed behavior produced a false negative in a real case.

### R4. Why follow-up issues get filed before the completion record cites them
A number chosen in advance — even a well-guessed "next" number — can silently collide
with an issue someone or something else creates in the gap between guessing and
filing. The wrong link this produces is permanent and gives no error. File first,
capture the real number, then write anything that cites it.

### R5. Why a deprecated file gets deleted, not kept behind a banner
A file kept only so its reasoning isn't lost is still loaded into every session's
context and still enumerated as an available command, whether or not the banner stops
it from being invoked. The banner stops invocation; it doesn't stop the recurring
cost. Move the reasoning somewhere not auto-loaded (here) and delete the file — that
keeps 100% of the knowledge at close to 0% of the recurring cost.

### R6. Why unused MCP servers get pruned rather than left connected
Every connected tool's schema is loaded into every request's context, used or not.
An MCP server that's unauthenticated, unreachable in a non-interactive session, or
simply never called by anything this project's workflow actually does is a fixed cost
paid on every single turn for zero benefit. Audit which servers this project's `gh`-
and file-based workflow actually calls, and disable the rest.

### R7. Why bundling reduces session count without reducing review
Every new session re-pays a large fixed context reload before any work happens.
Bundling small, closely-related work into one session avoids paying that repeatedly —
but the acceptance-criteria-per-issue property and one-PR-per-reviewed-unit property
both stay intact; each bundled issue still gets its own criteria checked and its own
line in the completion record. Bundling changes how many sessions something takes, not
how carefully any part of it gets reviewed. It's a request-count fix, not a
carefulness trade-off.

### R8. Why `/batch-issues`' batch has a ceiling instead of running indefinitely
Session cost grows faster than linearly as a session's own context grows — a real
session went from 39K to 174K tokens of context over 116 turns, meaning each
additional turn cost more than the last, not the same. An unbounded batch would
eventually make each additional issue in it *more* expensive than a fresh session
would have been, which defeats the reason to batch at all. A capped batch, then a
fresh context, keeps each issue's overhead bounded instead of compounding.

### R9. Why `/batch-issues` won't touch the env allowlist or the audit writer
Those two places are where the app's trust boundary is actually enforced
(`DESIGN.md` §2). A batch runs without a check-in between issues, which is exactly the
mode in which a subtly-wrong change to a security boundary gets a PR opened before
anyone's looked at it. The cost of excluding them is one extra `/start` session per
change; the cost of including them is a boundary edit that lands in a queue of three
PRs reviewed together. Same reasoning as the PRD's principle 3, applied to this
project's own development loop rather than the app it builds.
