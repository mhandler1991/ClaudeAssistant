## [#{issue}] {Issue title}

Closes #{issue}

### What
- 

### Decisions and what was rejected
<!-- Seeded from the commit body. If this is empty, the commit message was too thin. -->

### Files changed
- `path` — new / modified

### Checks
- [ ] `swift build` / `swift format lint` / `swift test` clean (or `bash -n scripts/*.sh` during Phase 0)
- [ ] No new code path that merges, force-pushes, or writes to a default branch
- [ ] Child-process environment still constructed from the allowlist only
- [ ] Limits and label names live in `Constants.swift`, not inline
- [ ] `docs/DESIGN.md` updated if the env allowlist, session protocol, or state machine changed
- [ ] `docs/PRD.md` updated if a product decision changed

---

<!-- For the dev → main promotion PR opened by /promote, replace everything above with: -->
<!--
## Promote dev → main

One line: what this release includes, or a pointer to the milestone.

- [ ] Checks green on `dev`
- [ ] Ran the app from `dev` against at least one real ticket
- [ ] Tagged as `v0.{phase}.{patch}` after merge
-->
