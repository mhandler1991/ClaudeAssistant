---
description: List this project's own .claude/skills/ commands and what each one does
allowed-tools: Bash(ls:*)
---

# This project's commands

!`ls -1 .claude/skills/`

Read each `SKILL.md` listed above with your Read tool (not a shell pipeline). For each
one except `commands` itself, report:

- `/{name}` — its `description` frontmatter field
- Whether it's `disable-model-invocation: true` (if so, note "you invoke this — Claude
  won't run it on its own")

For Claude Code's built-in commands, run `/help`. For every installed skill including
bundled ones (`/code-review`, `/debug`, `/run`, `/verify`, `/security-review`, etc.),
run `/skills`.
