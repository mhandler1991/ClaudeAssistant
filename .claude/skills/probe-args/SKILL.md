---
description: Throwaway — confirms positional argument indexing on this Claude Code install. Run once as `/probe-args alpha beta gamma`, then delete this directory.
disable-model-invocation: true
---

Probe result: $0 / $1 / $2 / $ARGUMENTS

Expected on the convention `start`, `merged`, and `batch-issues` were written against:
`alpha / beta / gamma / alpha beta gamma`. If `$0` is *not* `alpha`, the skills that
use `$0` need fixing before first use — say so. Either way, delete
`.claude/skills/probe-args/` once you've read this.
